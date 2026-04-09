package domain

import (
	"time"

	"github.com/google/uuid"
)

// Blog represents a blog post/announcement
type Blog struct {
	ID          uuid.UUID `json:"id" db:"id"`
	Title       string    `json:"title" db:"title"`
	Content     string    `json:"content" db:"content"`
	Excerpt     *string   `json:"excerpt,omitempty" db:"excerpt"`
	ImageURL    *string   `json:"image_url,omitempty" db:"image_url"`
	AuthorID    uuid.UUID `json:"author_id" db:"author_id"`
	AuthorName  *string   `json:"author_name,omitempty" db:"author_name"`
	IsPublished bool      `json:"is_published" db:"is_published"`
	ViewCount   int       `json:"view_count" db:"view_count"`
	CreatedAt   time.Time `json:"created_at" db:"created_at"`
	UpdatedAt   time.Time `json:"updated_at" db:"updated_at"`

	// Joined fields (not stored in DB)
	Author *User `json:"author,omitempty" db:"-"`
}

// CreateBlogRequest represents the request to create a blog post
type CreateBlogRequest struct {
	Title       string  `json:"title" binding:"required,min=1,max=500"`
	Content     string  `json:"content" binding:"required,min=1"`
	Excerpt     string  `json:"excerpt,omitempty"`
	ImageURL    string  `json:"image_url,omitempty"`
	IsPublished *bool   `json:"is_published,omitempty"`
}

// UpdateBlogRequest represents the request to update a blog post
type UpdateBlogRequest struct {
	Title       *string `json:"title,omitempty"`
	Content     *string `json:"content,omitempty"`
	Excerpt     *string `json:"excerpt,omitempty"`
	ImageURL    *string `json:"image_url,omitempty"`
	IsPublished *bool   `json:"is_published,omitempty"`
}

// BlogListResponse represents paginated blog list response
type BlogListResponse struct {
	Blogs      []*Blog `json:"blogs"`
	Total      int     `json:"total"`
	Page       int     `json:"page"`
	PageSize   int     `json:"page_size"`
	TotalPages int     `json:"total_pages"`
}

// BlogRepository defines the interface for blog data access
type BlogRepository interface {
	Create(blog *Blog) error
	GetByID(id uuid.UUID) (*Blog, error)
	GetAll(page, pageSize int, publishedOnly bool) ([]*Blog, int, error)
	Update(blog *Blog) error
	Delete(id uuid.UUID) error
	IncrementViewCount(id uuid.UUID) error
}

// BlogService defines the interface for blog business logic
type BlogService interface {
	CreateBlog(authorID uuid.UUID, authorName string, req *CreateBlogRequest) (*Blog, error)
	GetBlog(id uuid.UUID, incrementView bool) (*Blog, error)
	ListBlogs(page, pageSize int, publishedOnly bool) (*BlogListResponse, error)
	UpdateBlog(id, authorID uuid.UUID, req *UpdateBlogRequest) (*Blog, error)
	DeleteBlog(id, authorID uuid.UUID) error
	UploadImage(blogID uuid.UUID, imageData []byte, filename string) (string, error)
}
