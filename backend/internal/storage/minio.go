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

// InitMinIO initializes the global MinIO S3-compatible client
func InitMinIO(endpoint, accessKey, secretKey, bucket string, useSSL bool) error {
	client, err := minio.New(endpoint, &minio.Options{
		Creds:  credentials.NewStaticV4(accessKey, secretKey, ""),
		Secure: useSSL,
	})
	if err != nil {
		return fmt.Errorf("failed to initialize MinIO client: %w", err)
	}

	Client = client
	DefaultBucket = bucket
	logger.Log.Info("Connected to MinIO successfully", "endpoint", endpoint, "bucket", bucket)
	return nil
}

// UploadFile uploads a file to the default MinIO bucket and returns the public URL.
// objectName should be a unique path like "quotations/123/quote.pdf"
func UploadFile(ctx context.Context, objectName string, reader io.Reader, size int64, contentType string) (string, error) {
	_, err := Client.PutObject(ctx, DefaultBucket, objectName, reader, size, minio.PutObjectOptions{
		ContentType: contentType,
	})
	if err != nil {
		return "", fmt.Errorf("failed to upload to MinIO: %w", err)
	}

	// Build the public URL (works because minio-setup sets the bucket to public)
	url := fmt.Sprintf("http://%s/%s/%s", Client.EndpointURL().Host, DefaultBucket, objectName)
	return url, nil
}
