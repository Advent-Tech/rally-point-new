package service

import (
	"fmt"
	"math"
	"os"
	"path/filepath"
	"strings"
	"time"

	"rally-point/user-service/internal/domain"

	"github.com/google/uuid"
)

const (
	MaxImageFileSize = 10 * 1024 * 1024 // 10MB max image size
)

type blogService struct {
	blogRepo    domain.BlogRepository
	storagePath string
	baseURL     string
}

// NewBlogService creates a new blog service
func NewBlogService(blogRepo domain.BlogRepository, storagePath, baseURL string) domain.BlogService {
	return &blogService{
		blogRepo:    blogRepo,
		storagePath: storagePath,
		baseURL:     baseURL,
	}
}

// CreateBlog creates a new blog post
func (s *blogService) CreateBlog(authorID uuid.UUID, authorName string, req *domain.CreateBlogRequest) (*domain.Blog, error) {
	// Validate input
	if req.Title == "" {
		return nil, fmt.Errorf("title is required")
	}
	if req.Content == "" {
		return nil, fmt.Errorf("content is required")
	}

	now := time.Now()
	blog := &domain.Blog{
		ID:          uuid.New(),
		Title:       req.Title,
		Content:     req.Content,
		AuthorID:    authorID,
		IsPublished: true, // Default to published
		ViewCount:   0,
		CreatedAt:   now,
		UpdatedAt:   now,
	}

	// Set optional fields
	if req.Excerpt != "" {
		blog.Excerpt = &req.Excerpt
	} else {
		// Auto-generate excerpt from content
		excerpt := generateExcerpt(req.Content, 200)
		blog.Excerpt = &excerpt
	}

	if req.ImageURL != "" {
		blog.ImageURL = &req.ImageURL
	}

	if authorName != "" {
		blog.AuthorName = &authorName
	}

	if req.IsPublished != nil {
		blog.IsPublished = *req.IsPublished
	}

	err := s.blogRepo.Create(blog)
	if err != nil {
		return nil, fmt.Errorf("failed to create blog: %w", err)
	}

	fmt.Printf("📝 Blog created: %s by %s\n", blog.Title, authorName)

	return blog, nil
}

// GetBlog retrieves a blog by ID
func (s *blogService) GetBlog(id uuid.UUID, incrementView bool) (*domain.Blog, error) {
	blog, err := s.blogRepo.GetByID(id)
	if err != nil {
		return nil, err
	}

	// Increment view count if requested
	if incrementView {
		_ = s.blogRepo.IncrementViewCount(id)
		blog.ViewCount++
	}

	return blog, nil
}

// ListBlogs retrieves all blogs with pagination
func (s *blogService) ListBlogs(page, pageSize int, publishedOnly bool) (*domain.BlogListResponse, error) {
	if page < 1 {
		page = 1
	}
	if pageSize < 1 {
		pageSize = 10
	}
	if pageSize > 100 {
		pageSize = 100
	}

	blogs, total, err := s.blogRepo.GetAll(page, pageSize, publishedOnly)
	if err != nil {
		return nil, err
	}

	totalPages := int(math.Ceil(float64(total) / float64(pageSize)))

	return &domain.BlogListResponse{
		Blogs:      blogs,
		Total:      total,
		Page:       page,
		PageSize:   pageSize,
		TotalPages: totalPages,
	}, nil
}

// UpdateBlog updates a blog post
func (s *blogService) UpdateBlog(id, authorID uuid.UUID, req *domain.UpdateBlogRequest) (*domain.Blog, error) {
	// Get existing blog
	blog, err := s.blogRepo.GetByID(id)
	if err != nil {
		return nil, err
	}

	// Verify author (or could be admin - for now we'll check author only)
	// Note: In production, you might want to also check if user is admin
	if blog.AuthorID != authorID {
		return nil, fmt.Errorf("you can only edit your own blogs")
	}

	// Update fields if provided
	if req.Title != nil {
		blog.Title = *req.Title
	}
	if req.Content != nil {
		blog.Content = *req.Content
		// Update excerpt if not explicitly set
		if req.Excerpt == nil {
			excerpt := generateExcerpt(*req.Content, 200)
			blog.Excerpt = &excerpt
		}
	}
	if req.Excerpt != nil {
		blog.Excerpt = req.Excerpt
	}
	if req.ImageURL != nil {
		blog.ImageURL = req.ImageURL
	}
	if req.IsPublished != nil {
		blog.IsPublished = *req.IsPublished
	}

	err = s.blogRepo.Update(blog)
	if err != nil {
		return nil, fmt.Errorf("failed to update blog: %w", err)
	}

	fmt.Printf("📝 Blog updated: %s\n", blog.Title)

	return blog, nil
}

// DeleteBlog deletes a blog post
func (s *blogService) DeleteBlog(id, authorID uuid.UUID) error {
	// Get existing blog
	blog, err := s.blogRepo.GetByID(id)
	if err != nil {
		return err
	}

	// Verify author (or admin)
	if blog.AuthorID != authorID {
		return fmt.Errorf("you can only delete your own blogs")
	}

	// Delete associated image if exists
	if blog.ImageURL != nil && strings.Contains(*blog.ImageURL, "/uploads/blogs/") {
		imagePath := filepath.Join(s.storagePath, filepath.Base(*blog.ImageURL))
		os.Remove(imagePath) // Ignore error if file doesn't exist
	}

	err = s.blogRepo.Delete(id)
	if err != nil {
		return fmt.Errorf("failed to delete blog: %w", err)
	}

	fmt.Printf("🗑️ Blog deleted: %s\n", blog.Title)

	return nil
}

// UploadImage uploads an image for a blog post
func (s *blogService) UploadImage(blogID uuid.UUID, imageData []byte, filename string) (string, error) {
	// Validate image size
	if len(imageData) > MaxImageFileSize {
		return "", fmt.Errorf("image file too large (max %d MB)", MaxImageFileSize/(1024*1024))
	}

	// Validate file extension
	ext := strings.ToLower(filepath.Ext(filename))
	validExtensions := map[string]bool{
		".jpg":  true,
		".jpeg": true,
		".png":  true,
		".gif":  true,
		".webp": true,
	}

	if !validExtensions[ext] {
		return "", fmt.Errorf("invalid image format. Supported: jpg, jpeg, png, gif, webp")
	}

	// Create storage directory
	blogStoragePath := filepath.Join(s.storagePath, "blogs")
	err := os.MkdirAll(blogStoragePath, 0755)
	if err != nil {
		return "", fmt.Errorf("failed to create storage directory: %w", err)
	}

	// Generate unique filename
	uniqueFilename := fmt.Sprintf("%s_%s%s", blogID.String(), uuid.New().String()[:8], ext)
	filePath := filepath.Join(blogStoragePath, uniqueFilename)

	// Write file
	err = os.WriteFile(filePath, imageData, 0644)
	if err != nil {
		return "", fmt.Errorf("failed to save image: %w", err)
	}

	// Generate URL
	imageURL := fmt.Sprintf("%s/uploads/blogs/%s", s.baseURL, uniqueFilename)

	fmt.Printf("📷 Image uploaded for blog %s: %s\n", blogID, uniqueFilename)

	return imageURL, nil
}

// generateExcerpt creates a short excerpt from content
func generateExcerpt(content string, maxLength int) string {
	// Remove HTML tags (basic)
	content = strings.ReplaceAll(content, "<br>", " ")
	content = strings.ReplaceAll(content, "<br/>", " ")
	content = strings.ReplaceAll(content, "<br />", " ")
	content = strings.ReplaceAll(content, "</p>", " ")
	content = strings.ReplaceAll(content, "<p>", "")

	// Remove multiple spaces
	for strings.Contains(content, "  ") {
		content = strings.ReplaceAll(content, "  ", " ")
	}

	content = strings.TrimSpace(content)

	if len(content) <= maxLength {
		return content
	}

	// Find last space before maxLength
	excerpt := content[:maxLength]
	lastSpace := strings.LastIndex(excerpt, " ")
	if lastSpace > maxLength/2 {
		excerpt = excerpt[:lastSpace]
	}

	return excerpt + "..."
}
