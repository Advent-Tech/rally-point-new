package email

import (
	"crypto/tls"
	"fmt"
	"net/smtp"
	"os"
	"strconv"
	"strings"
)

// SMTPConfig holds SMTP configuration
type SMTPConfig struct {
	Host     string
	Port     int
	Username string
	Password string
	From     string
	FromName string
}

// EmailClient handles email sending
type EmailClient struct {
	config SMTPConfig
}

// NewEmailClient creates a new email client from environment variables
func NewEmailClient() *EmailClient {
	port, _ := strconv.Atoi(os.Getenv("SMTP_PORT"))
	if port == 0 {
		port = 587
	}

	return &EmailClient{
		config: SMTPConfig{
			Host:     os.Getenv("SMTP_HOST"),
			Port:     port,
			Username: os.Getenv("SMTP_USERNAME"),
			Password: os.Getenv("SMTP_PASSWORD"),
			From:     os.Getenv("SMTP_FROM"),
			FromName: os.Getenv("SMTP_FROM_NAME"),
		},
	}
}

// NewEmailClientWithConfig creates a new email client with the given config
func NewEmailClientWithConfig(config SMTPConfig) *EmailClient {
	return &EmailClient{config: config}
}

// SendEmail sends an email with the given parameters
func (c *EmailClient) SendEmail(to, subject, htmlBody, textBody string) error {
	if !c.IsConfigured() {
		return fmt.Errorf("email client not configured")
	}

	// Build email message with MIME multipart
	message := c.buildMessage(to, subject, htmlBody, textBody)

	// Try TLS first, then fallback to STARTTLS
	err := c.sendWithTLS(to, message)
	if err != nil {
		// Fallback to STARTTLS
		err = c.sendWithSTARTTLS(to, message)
	}

	return err
}

// buildMessage constructs the email message with MIME multipart
func (c *EmailClient) buildMessage(to, subject, htmlBody, textBody string) string {
	boundary := "----=_Part_0_1234567890.1234567890"

	var sb strings.Builder

	// Headers
	sb.WriteString(fmt.Sprintf("From: %s <%s>\r\n", c.config.FromName, c.config.From))
	sb.WriteString(fmt.Sprintf("To: %s\r\n", to))
	sb.WriteString(fmt.Sprintf("Subject: %s\r\n", subject))
	sb.WriteString("MIME-Version: 1.0\r\n")
	sb.WriteString(fmt.Sprintf("Content-Type: multipart/alternative; boundary=\"%s\"\r\n", boundary))
	sb.WriteString("\r\n")

	// Plain text part
	sb.WriteString(fmt.Sprintf("--%s\r\n", boundary))
	sb.WriteString("Content-Type: text/plain; charset=\"UTF-8\"\r\n")
	sb.WriteString("Content-Transfer-Encoding: quoted-printable\r\n")
	sb.WriteString("\r\n")
	sb.WriteString(textBody)
	sb.WriteString("\r\n")

	// HTML part
	sb.WriteString(fmt.Sprintf("--%s\r\n", boundary))
	sb.WriteString("Content-Type: text/html; charset=\"UTF-8\"\r\n")
	sb.WriteString("Content-Transfer-Encoding: quoted-printable\r\n")
	sb.WriteString("\r\n")
	sb.WriteString(htmlBody)
	sb.WriteString("\r\n")

	// End boundary
	sb.WriteString(fmt.Sprintf("--%s--\r\n", boundary))

	return sb.String()
}

// sendWithTLS sends email using direct TLS connection (port 465)
func (c *EmailClient) sendWithTLS(to, message string) error {
	addr := fmt.Sprintf("%s:%d", c.config.Host, c.config.Port)

	tlsConfig := &tls.Config{
		ServerName: c.config.Host,
	}

	conn, err := tls.Dial("tcp", addr, tlsConfig)
	if err != nil {
		return fmt.Errorf("TLS dial failed: %w", err)
	}
	defer conn.Close()

	client, err := smtp.NewClient(conn, c.config.Host)
	if err != nil {
		return fmt.Errorf("SMTP client creation failed: %w", err)
	}
	defer client.Close()

	// Authenticate
	auth := smtp.PlainAuth("", c.config.Username, c.config.Password, c.config.Host)
	if err = client.Auth(auth); err != nil {
		return fmt.Errorf("SMTP auth failed: %w", err)
	}

	// Send email
	if err = client.Mail(c.config.From); err != nil {
		return fmt.Errorf("MAIL FROM failed: %w", err)
	}

	if err = client.Rcpt(to); err != nil {
		return fmt.Errorf("RCPT TO failed: %w", err)
	}

	w, err := client.Data()
	if err != nil {
		return fmt.Errorf("DATA failed: %w", err)
	}

	_, err = w.Write([]byte(message))
	if err != nil {
		return fmt.Errorf("write message failed: %w", err)
	}

	err = w.Close()
	if err != nil {
		return fmt.Errorf("close message failed: %w", err)
	}

	return client.Quit()
}

// sendWithSTARTTLS sends email using STARTTLS (port 587)
func (c *EmailClient) sendWithSTARTTLS(to, message string) error {
	addr := fmt.Sprintf("%s:%d", c.config.Host, c.config.Port)
	auth := smtp.PlainAuth("", c.config.Username, c.config.Password, c.config.Host)

	return smtp.SendMail(addr, auth, c.config.From, []string{to}, []byte(message))
}

// IsConfigured checks if email is properly configured
func (c *EmailClient) IsConfigured() bool {
	return c.config.Host != "" &&
		c.config.Username != "" &&
		c.config.Password != "" &&
		c.config.From != ""
}

// GetConfig returns the current configuration (for debugging)
func (c *EmailClient) GetConfig() SMTPConfig {
	// Return a copy with password masked
	return SMTPConfig{
		Host:     c.config.Host,
		Port:     c.config.Port,
		Username: c.config.Username,
		Password: "********",
		From:     c.config.From,
		FromName: c.config.FromName,
	}
}
