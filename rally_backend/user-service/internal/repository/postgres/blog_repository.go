package postgres

import (
	"database/sql"
	"fmt"
	"math"
	"time"

	"github.com/google/uuid"
	"rally-point/user-service/internal/domain"
)

type blogRepository struct {
	db *sql.DB
}

// NewBlogRepository creates a new blog repository
func NewBlogRepository(db *sql.DB) domain.BlogRepository {
	return &blogRepository{db: db}
}

// Create creates a new blog post
func (r *blogRepository) Create(blog *domain.Blog) error {
	query := `
		INSERT INTO blogs (id, title, content, excerpt, image_url, author_id, author_name, is_published, view_count, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
	`

	_, err := r.db.Exec(
		query,
		blog.ID,
		blog.Title,
		blog.Content,
		blog.Excerpt,
		blog.ImageURL,
		blog.AuthorID,
		blog.AuthorName,
		blog.IsPublished,
		blog.ViewCount,
		blog.CreatedAt,
		blog.UpdatedAt,
	)

	if err != nil {
		return fmt.Errorf("failed to create blog: %w", err)
	}

	return nil
}

// GetByID retrieves a blog by ID
func (r *blogRepository) GetByID(id uuid.UUID) (*domain.Blog, error) {
	query := `
		SELECT b.id, b.title, b.content, b.excerpt, b.image_url, b.author_id, b.author_name,
		       b.is_published, b.view_count, b.created_at, b.updated_at,
		       u.display_name, u.email, u.profile_photo_url
		FROM blogs b
		LEFT JOIN users u ON u.id = b.author_id
		WHERE b.id = $1
	`

	blog := &domain.Blog{}
	var authorDisplayName, authorEmail sql.NullString
	var authorProfilePhoto sql.NullString

	err := r.db.QueryRow(query, id).Scan(
		&blog.ID,
		&blog.Title,
		&blog.Content,
		&blog.Excerpt,
		&blog.ImageURL,
		&blog.AuthorID,
		&blog.AuthorName,
		&blog.IsPublished,
		&blog.ViewCount,
		&blog.CreatedAt,
		&blog.UpdatedAt,
		&authorDisplayName,
		&authorEmail,
		&authorProfilePhoto,
	)

	if err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("blog not found")
		}
		return nil, fmt.Errorf("failed to get blog: %w", err)
	}

	// Set author details
	if authorDisplayName.Valid {
		blog.Author = &domain.User{
			ID:          blog.AuthorID,
			DisplayName: authorDisplayName.String,
			Email:       authorEmail.String,
		}
		if authorProfilePhoto.Valid {
			blog.Author.ProfilePhotoURL = &authorProfilePhoto.String
		}
	}

	return blog, nil
}

// GetAll retrieves all blogs with pagination
func (r *blogRepository) GetAll(page, pageSize int, publishedOnly bool) ([]*domain.Blog, int, error) {
	// Calculate offset
	offset := (page - 1) * pageSize

	// Build query based on publishedOnly flag
	var countQuery, selectQuery string
	var args []interface{}

	if publishedOnly {
		countQuery = `SELECT COUNT(*) FROM blogs WHERE is_published = true`
		selectQuery = `
			SELECT b.id, b.title, b.content, b.excerpt, b.image_url, b.author_id, b.author_name,
			       b.is_published, b.view_count, b.created_at, b.updated_at,
			       u.display_name, u.email, u.profile_photo_url
			FROM blogs b
			LEFT JOIN users u ON u.id = b.author_id
			WHERE b.is_published = true
			ORDER BY b.created_at DESC
			LIMIT $1 OFFSET $2
		`
		args = []interface{}{pageSize, offset}
	} else {
		countQuery = `SELECT COUNT(*) FROM blogs`
		selectQuery = `
			SELECT b.id, b.title, b.content, b.excerpt, b.image_url, b.author_id, b.author_name,
			       b.is_published, b.view_count, b.created_at, b.updated_at,
			       u.display_name, u.email, u.profile_photo_url
			FROM blogs b
			LEFT JOIN users u ON u.id = b.author_id
			ORDER BY b.created_at DESC
			LIMIT $1 OFFSET $2
		`
		args = []interface{}{pageSize, offset}
	}

	// Get total count
	var total int
	err := r.db.QueryRow(countQuery).Scan(&total)
	if err != nil {
		return nil, 0, fmt.Errorf("failed to count blogs: %w", err)
	}

	// Get blogs
	rows, err := r.db.Query(selectQuery, args...)
	if err != nil {
		return nil, 0, fmt.Errorf("failed to get blogs: %w", err)
	}
	defer rows.Close()

	var blogs []*domain.Blog
	for rows.Next() {
		blog := &domain.Blog{}
		var authorDisplayName, authorEmail sql.NullString
		var authorProfilePhoto sql.NullString

		err := rows.Scan(
			&blog.ID,
			&blog.Title,
			&blog.Content,
			&blog.Excerpt,
			&blog.ImageURL,
			&blog.AuthorID,
			&blog.AuthorName,
			&blog.IsPublished,
			&blog.ViewCount,
			&blog.CreatedAt,
			&blog.UpdatedAt,
			&authorDisplayName,
			&authorEmail,
			&authorProfilePhoto,
		)
		if err != nil {
			return nil, 0, fmt.Errorf("failed to scan blog: %w", err)
		}

		// Set author details
		if authorDisplayName.Valid {
			blog.Author = &domain.User{
				ID:          blog.AuthorID,
				DisplayName: authorDisplayName.String,
				Email:       authorEmail.String,
			}
			if authorProfilePhoto.Valid {
				blog.Author.ProfilePhotoURL = &authorProfilePhoto.String
			}
		}

		blogs = append(blogs, blog)
	}

	return blogs, total, nil
}

// Update updates a blog
func (r *blogRepository) Update(blog *domain.Blog) error {
	query := `
		UPDATE blogs
		SET title = $2, content = $3, excerpt = $4, image_url = $5, is_published = $6, updated_at = $7
		WHERE id = $1
	`

	blog.UpdatedAt = time.Now()

	result, err := r.db.Exec(
		query,
		blog.ID,
		blog.Title,
		blog.Content,
		blog.Excerpt,
		blog.ImageURL,
		blog.IsPublished,
		blog.UpdatedAt,
	)

	if err != nil {
		return fmt.Errorf("failed to update blog: %w", err)
	}

	rowsAffected, _ := result.RowsAffected()
	if rowsAffected == 0 {
		return fmt.Errorf("blog not found")
	}

	return nil
}

// Delete deletes a blog
func (r *blogRepository) Delete(id uuid.UUID) error {
	query := `DELETE FROM blogs WHERE id = $1`

	result, err := r.db.Exec(query, id)
	if err != nil {
		return fmt.Errorf("failed to delete blog: %w", err)
	}

	rowsAffected, _ := result.RowsAffected()
	if rowsAffected == 0 {
		return fmt.Errorf("blog not found")
	}

	return nil
}

// IncrementViewCount increments the view count for a blog
func (r *blogRepository) IncrementViewCount(id uuid.UUID) error {
	query := `UPDATE blogs SET view_count = view_count + 1 WHERE id = $1`

	_, err := r.db.Exec(query, id)
	if err != nil {
		return fmt.Errorf("failed to increment view count: %w", err)
	}

	return nil
}

// Helper function to calculate total pages
func calculateTotalPages(total, pageSize int) int {
	return int(math.Ceil(float64(total) / float64(pageSize)))
}
