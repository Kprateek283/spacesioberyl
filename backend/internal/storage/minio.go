package storage

import (
	"context"
	"fmt"
	"io"

	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"
	"github.com/spacesioberyl/system-v1/internal/logger"
)

// Client is the global MinIO client instance
var Client *minio.Client

// DefaultBucket is the bucket name for CRM files (PDFs, receipts, photos)
var DefaultBucket string

// PublicURL is the base URL accessible by external clients
var PublicURL string

// InitMinIO initializes the global MinIO S3-compatible client
func InitMinIO(endpoint, accessKey, secretKey, bucket string, useSSL bool, publicURL string) error {
	client, err := minio.New(endpoint, &minio.Options{
		Creds:  credentials.NewStaticV4(accessKey, secretKey, ""),
		Secure: useSSL,
	})
	if err != nil {
		return fmt.Errorf("failed to initialize MinIO client: %w", err)
	}

	Client = client
	DefaultBucket = bucket
	PublicURL = publicURL
	logger.Log.Info("Connected to MinIO successfully", "endpoint", endpoint, "bucket", bucket)
	return nil
}

// UploadFile uploads a file to the default (now private) MinIO bucket and returns
// the object KEY — not a public URL. The bucket is no longer world-readable
// (backend-bugs #12), so callers store the key and serve it through the
// authenticated /api/v1/files endpoint. objectName should be a server-generated
// unique key like "quotations/123/<uuid>.pdf".
func UploadFile(ctx context.Context, objectName string, reader io.Reader, size int64, contentType string) (string, error) {
	// Defence in depth: init is fatal at boot, but if that ever changes a nil
	// client must return a clear error rather than panic mid-request (backend-bugs #18).
	if Client == nil {
		return "", fmt.Errorf("storage unavailable: MinIO client is not initialized")
	}
	_, err := Client.PutObject(ctx, DefaultBucket, objectName, reader, size, minio.PutObjectOptions{
		ContentType: contentType,
	})
	if err != nil {
		return "", fmt.Errorf("failed to upload to MinIO: %w", err)
	}
	return objectName, nil
}

// DownloadFile streams an object out of the private bucket for an authenticated
// caller. It returns the object's content type alongside the reader so the HTTP
// handler can set it. The caller must Close the reader.
func DownloadFile(ctx context.Context, key string) (io.ReadCloser, string, error) {
	if Client == nil {
		return nil, "", fmt.Errorf("storage unavailable: MinIO client is not initialized")
	}
	// StatObject both confirms existence (so a missing key is a clean 404, not a
	// stream error mid-copy) and gives us the stored content type.
	info, err := Client.StatObject(ctx, DefaultBucket, key, minio.StatObjectOptions{})
	if err != nil {
		return nil, "", err
	}
	obj, err := Client.GetObject(ctx, DefaultBucket, key, minio.GetObjectOptions{})
	if err != nil {
		return nil, "", err
	}
	contentType := info.ContentType
	if contentType == "" {
		contentType = "application/octet-stream"
	}
	return obj, contentType, nil
}
