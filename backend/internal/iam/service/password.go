package service

import "golang.org/x/crypto/bcrypt"

// HashPassword generates a bcrypt hash of the given password
func HashPassword(password string) (string, error) {
	bytes, err := bcrypt.GenerateFromPassword([]byte(password), 10) // Cost of 10 is standard
	return string(bytes), err
}

// CheckPasswordHash compares a raw password against a stored bcrypt hash
func CheckPasswordHash(password, hash string) bool {
	err := bcrypt.CompareHashAndPassword([]byte(hash), []byte(password))
	return err == nil
}
