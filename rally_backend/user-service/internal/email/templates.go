package email

import (
	"bytes"
	"html/template"
	"os"
)

// EmailTemplates holds all email template generators
type EmailTemplates struct {
	frontendURL string
}

// NewEmailTemplates creates a new template generator
func NewEmailTemplates() *EmailTemplates {
	frontendURL := os.Getenv("FRONTEND_URL")
	if frontendURL == "" {
		frontendURL = "http://localhost:3000"
	}
	return &EmailTemplates{
		frontendURL: frontendURL,
	}
}

// VerificationEmailData holds data for verification email
type VerificationEmailData struct {
	UserName        string
	VerificationURL string
	ExpiryHours     int
}

// PasswordResetEmailData holds data for password reset email
type PasswordResetEmailData struct {
	UserName      string
	ResetURL      string
	ExpiryMinutes int
}

// GenerateVerificationEmail generates HTML and text versions of verification email
func (t *EmailTemplates) GenerateVerificationEmail(data VerificationEmailData) (html, text string, err error) {
	htmlTmpl := `<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
            line-height: 1.6;
            color: #333;
            margin: 0;
            padding: 0;
            background-color: #f5f5f5;
        }
        .container {
            max-width: 600px;
            margin: 0 auto;
            padding: 20px;
        }
        .header {
            background-color: #4A90D9;
            color: white;
            padding: 30px 20px;
            text-align: center;
            border-radius: 8px 8px 0 0;
        }
        .header h1 {
            margin: 0;
            font-size: 28px;
            font-weight: 600;
        }
        .content {
            padding: 30px;
            background-color: #ffffff;
            border-radius: 0 0 8px 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .content h2 {
            color: #333;
            margin-top: 0;
        }
        .button {
            display: inline-block;
            background-color: #4A90D9;
            color: white !important;
            padding: 14px 28px;
            text-decoration: none;
            border-radius: 6px;
            margin: 20px 0;
            font-weight: 600;
            font-size: 16px;
        }
        .button:hover {
            background-color: #357ABD;
        }
        .link-text {
            word-break: break-all;
            color: #666;
            font-size: 14px;
            background-color: #f9f9f9;
            padding: 10px;
            border-radius: 4px;
            margin: 10px 0;
        }
        .footer {
            padding: 20px;
            text-align: center;
            color: #666;
            font-size: 12px;
        }
        .warning {
            background-color: #FFF3CD;
            border: 1px solid #FFE69C;
            padding: 12px;
            border-radius: 6px;
            margin-top: 20px;
            font-size: 14px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>Rally Point</h1>
        </div>
        <div class="content">
            <h2>Verify Your Email Address</h2>
            <p>Hello {{.UserName}},</p>
            <p>Thank you for registering with Rally Point. To complete your registration, please verify your email address by clicking the button below:</p>
            <p style="text-align: center;">
                <a href="{{.VerificationURL}}" class="button">Verify Email Address</a>
            </p>
            <p>Or copy and paste this link into your browser:</p>
            <p class="link-text">{{.VerificationURL}}</p>
            <div class="warning">
                <strong>Note:</strong> This link will expire in {{.ExpiryHours}} hours. If you did not create an account with Rally Point, please ignore this email.
            </div>
        </div>
        <div class="footer">
            <p>&copy; Rally Point. All rights reserved.</p>
            <p>This is an automated message, please do not reply.</p>
        </div>
    </div>
</body>
</html>`

	textTmpl := `Rally Point - Verify Your Email Address

Hello {{.UserName}},

Thank you for registering with Rally Point. To complete your registration, please verify your email address by clicking the link below:

{{.VerificationURL}}

This link will expire in {{.ExpiryHours}} hours.

If you did not create an account with Rally Point, please ignore this email.

---
Rally Point
This is an automated message, please do not reply.`

	var htmlBuf, textBuf bytes.Buffer

	htmlTemplate, err := template.New("html").Parse(htmlTmpl)
	if err != nil {
		return "", "", err
	}
	if err = htmlTemplate.Execute(&htmlBuf, data); err != nil {
		return "", "", err
	}

	textTemplate, err := template.New("text").Parse(textTmpl)
	if err != nil {
		return "", "", err
	}
	if err = textTemplate.Execute(&textBuf, data); err != nil {
		return "", "", err
	}

	return htmlBuf.String(), textBuf.String(), nil
}

// GeneratePasswordResetEmail generates HTML and text versions of password reset email
func (t *EmailTemplates) GeneratePasswordResetEmail(data PasswordResetEmailData) (html, text string, err error) {
	htmlTmpl := `<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
            line-height: 1.6;
            color: #333;
            margin: 0;
            padding: 0;
            background-color: #f5f5f5;
        }
        .container {
            max-width: 600px;
            margin: 0 auto;
            padding: 20px;
        }
        .header {
            background-color: #4A90D9;
            color: white;
            padding: 30px 20px;
            text-align: center;
            border-radius: 8px 8px 0 0;
        }
        .header h1 {
            margin: 0;
            font-size: 28px;
            font-weight: 600;
        }
        .content {
            padding: 30px;
            background-color: #ffffff;
            border-radius: 0 0 8px 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .content h2 {
            color: #333;
            margin-top: 0;
        }
        .button {
            display: inline-block;
            background-color: #E74C3C;
            color: white !important;
            padding: 14px 28px;
            text-decoration: none;
            border-radius: 6px;
            margin: 20px 0;
            font-weight: 600;
            font-size: 16px;
        }
        .button:hover {
            background-color: #C0392B;
        }
        .link-text {
            word-break: break-all;
            color: #666;
            font-size: 14px;
            background-color: #f9f9f9;
            padding: 10px;
            border-radius: 4px;
            margin: 10px 0;
        }
        .footer {
            padding: 20px;
            text-align: center;
            color: #666;
            font-size: 12px;
        }
        .warning {
            background-color: #FDEDEC;
            border: 1px solid #F5B7B1;
            padding: 12px;
            border-radius: 6px;
            margin-top: 20px;
            font-size: 14px;
        }
        .security-notice {
            background-color: #FFF3CD;
            border: 1px solid #FFE69C;
            padding: 12px;
            border-radius: 6px;
            margin-top: 15px;
            font-size: 14px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>Rally Point</h1>
        </div>
        <div class="content">
            <h2>Reset Your Password</h2>
            <p>Hello {{.UserName}},</p>
            <p>We received a request to reset your password. Click the button below to create a new password:</p>
            <p style="text-align: center;">
                <a href="{{.ResetURL}}" class="button">Reset Password</a>
            </p>
            <p>Or copy and paste this link into your browser:</p>
            <p class="link-text">{{.ResetURL}}</p>
            <div class="warning">
                <strong>Security Notice:</strong> This link will expire in {{.ExpiryMinutes}} minutes for your security.
            </div>
            <div class="security-notice">
                <strong>Didn't request this?</strong> If you did not request a password reset, please ignore this email. Your password will remain unchanged and your account is secure.
            </div>
        </div>
        <div class="footer">
            <p>&copy; Rally Point. All rights reserved.</p>
            <p>This is an automated message, please do not reply.</p>
        </div>
    </div>
</body>
</html>`

	textTmpl := `Rally Point - Reset Your Password

Hello {{.UserName}},

We received a request to reset your password. Click the link below to create a new password:

{{.ResetURL}}

SECURITY NOTICE: This link will expire in {{.ExpiryMinutes}} minutes for your security.

Didn't request this? If you did not request a password reset, please ignore this email. Your password will remain unchanged and your account is secure.

---
Rally Point
This is an automated message, please do not reply.`

	var htmlBuf, textBuf bytes.Buffer

	htmlTemplate, err := template.New("html").Parse(htmlTmpl)
	if err != nil {
		return "", "", err
	}
	if err = htmlTemplate.Execute(&htmlBuf, data); err != nil {
		return "", "", err
	}

	textTemplate, err := template.New("text").Parse(textTmpl)
	if err != nil {
		return "", "", err
	}
	if err = textTemplate.Execute(&textBuf, data); err != nil {
		return "", "", err
	}

	return htmlBuf.String(), textBuf.String(), nil
}

// GetVerificationURL constructs the full verification URL
func (t *EmailTemplates) GetVerificationURL(token string) string {
	return t.frontendURL + "/verify-email?token=" + token
}

// GetPasswordResetURL constructs the full password reset URL
func (t *EmailTemplates) GetPasswordResetURL(token string) string {
	return t.frontendURL + "/reset-password?token=" + token
}

// SetFrontendURL allows updating the frontend URL (useful for testing)
func (t *EmailTemplates) SetFrontendURL(url string) {
	t.frontendURL = url
}
