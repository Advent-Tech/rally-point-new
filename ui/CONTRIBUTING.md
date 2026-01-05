# Contributing to Rally Point

Thank you for your interest in contributing to Rally Point! This document provides guidelines and instructions for contributing to the project.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Workflow](#development-workflow)
- [Coding Standards](#coding-standards)
- [Commit Guidelines](#commit-guidelines)
- [Pull Request Process](#pull-request-process)
- [Testing](#testing)
- [Documentation](#documentation)

## Code of Conduct

By participating in this project, you agree to maintain a respectful and inclusive environment for all contributors.

## Getting Started

1. **Fork the repository** on GitHub
2. **Clone your fork** locally:
   ```bash
   git clone https://github.com/your-username/rally-point-app.git
   cd rally-point-app
   ```
3. **Add upstream remote**:
   ```bash
   git remote add upstream https://github.com/original-owner/rally-point-app.git
   ```
4. **Install dependencies**:
   ```bash
   npm install --legacy-peer-deps
   ```
5. **Set up Firebase** (see README.md for details)
6. **Create a feature branch**:
   ```bash
   git checkout -b feature/your-feature-name
   ```

## Development Workflow

### Branch Naming Convention

- `feature/` - New features (e.g., `feature/team-messaging`)
- `fix/` - Bug fixes (e.g., `fix/login-error`)
- `refactor/` - Code refactoring (e.g., `refactor/auth-service`)
- `docs/` - Documentation updates (e.g., `docs/api-documentation`)
- `test/` - Test additions or updates (e.g., `test/survey-service`)

### Keeping Your Fork Updated

```bash
git fetch upstream
git checkout main
git merge upstream/main
git push origin main
```

## Coding Standards

### TypeScript

- **Use TypeScript** for all new files
- **Define interfaces** for all data structures
- **Avoid `any` type** - use proper typing
- **Use functional components** with hooks (no class components)
- **Export types** from appropriate files in `src/types/`

### React Native Best Practices

- **Functional Components**: Use functional components with hooks
- **Component Structure**:
  ```typescript
  // 1. Imports
  import React, { useState, useEffect } from 'react';
  import { View, Text } from 'react-native';
  
  // 2. Types/Interfaces
  interface MyComponentProps {
    title: string;
    onPress: () => void;
  }
  
  // 3. Component
  export const MyComponent: React.FC<MyComponentProps> = ({ title, onPress }) => {
    // 4. Hooks
    const [state, setState] = useState<string>('');
    
    // 5. Effects
    useEffect(() => {
      // Effect logic
    }, []);
    
    // 6. Handlers
    const handlePress = () => {
      onPress();
    };
    
    // 7. Render
    return (
      <View>
        <Text>{title}</Text>
      </View>
    );
  };
  
  // 8. Styles (if using StyleSheet)
  const styles = StyleSheet.create({
    container: {
      flex: 1,
    },
  });
  ```

### Styling

- **Use NativeWind** (Tailwind CSS) for styling
- **Follow existing patterns** in the codebase
- **Use constants** from `src/constants/Colors.ts` for brand colors
- **Responsive design**: Test on both mobile and tablet sizes

### Service Layer

- **Business logic** should be in service files (`src/services/`)
- **Firebase operations** should be abstracted in services
- **Error handling**: Always wrap Firebase calls in try-catch
- **Return consistent response format**:
  ```typescript
  return { success: true, data: result };
  // or
  return { success: false, error: 'Error message' };
  ```

### File Organization

- **Components**: `src/components/` - Reusable UI components
- **Screens**: `src/screens/` - Screen-level components
- **Services**: `src/services/` - Business logic and API calls
- **Types**: `src/types/` - TypeScript interfaces and types
- **Utils**: `src/utils/` - Utility functions
- **Hooks**: `src/hooks/` - Custom React hooks

## Commit Guidelines

### Commit Message Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Types

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, no logic change)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

### Examples

```
feat(auth): add Google Sign-In support

Implemented Google authentication using Firebase Auth
and @react-native-google-signin/google-signin package.

Closes #123
```

```
fix(survey): resolve survey submission error

Fixed issue where surveys weren't submitting when offline.
Added proper error handling and retry logic.

Fixes #456
```

## Pull Request Process

1. **Update your branch** with the latest main:
   ```bash
   git fetch upstream
   git rebase upstream/main
   ```

2. **Run tests** and ensure they pass:
   ```bash
   npm test
   ```

3. **Check for linting errors**:
   ```bash
   npm run lint
   ```

4. **Build the project** to ensure no build errors:
   ```bash
   npm run build
   ```

5. **Push to your fork**:
   ```bash
   git push origin feature/your-feature-name
   ```

6. **Create a Pull Request** on GitHub with:
   - Clear title describing the change
   - Detailed description of what was changed and why
   - Screenshots (for UI changes)
   - Reference to related issues (e.g., "Closes #123")
   - Test results

7. **Address review feedback** promptly

8. **Squash commits** if requested before merging

## Testing

### Running Tests

```bash
# Run all tests
npm test

# Run tests in watch mode
npm run test:watch

# Generate coverage report
npm run test:coverage
```

### Writing Tests

- **Unit tests** for services and utilities
- **Component tests** for UI components
- **Integration tests** for complex workflows
- **Aim for >80% code coverage** for new code

### Test File Naming

- Place tests in `__tests__` folders or alongside files with `.test.ts` suffix
- Example: `src/services/__tests__/TeamService.test.ts`

## Documentation

### Code Documentation

- **JSDoc comments** for public functions and complex logic
- **Inline comments** for non-obvious code
- **README updates** for new features or setup changes

### Example JSDoc

```typescript
/**
 * Creates a new team with the specified details
 * 
 * @param teamData - The team information including name, description, and leader
 * @returns Promise resolving to the created team ID
 * @throws Error if team creation fails
 * 
 * @example
 * ```typescript
 * const teamId = await TeamService.createTeam({
 *   name: 'North District',
 *   description: 'Team for north district operations',
 *   leaderId: 'user123'
 * });
 * ```
 */
async createTeam(teamData: TeamData): Promise<string> {
  // Implementation
}
```

## Questions?

If you have questions or need help:
- Open an issue on GitHub
- Contact the maintainers
- Check existing documentation

Thank you for contributing to Rally Point! 🎉

