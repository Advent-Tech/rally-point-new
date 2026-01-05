import * as yup from 'yup';

export const signInSchema = yup.object().shape({
  email: yup
    .string()
    .email('Please enter a valid email address')
    .required('Email is required'),
  password: yup
    .string()
    .min(6, 'Password must be at least 6 characters')
    .required('Password is required'),
});

export const signUpSchema = yup.object().shape({
  email: yup
    .string()
    .email('Please enter a valid email address')
    .required('Email is required'),
  password: yup
    .string()
    .min(6, 'Password must be at least 6 characters')
    .required('Password is required'),
  confirmPassword: yup
    .string()
    .oneOf([yup.ref('password')], 'Passwords must match')
    .required('Please confirm your password'),
  displayName: yup
    .string()
    .min(2, 'Name must be at least 2 characters')
    .required('Display name is required'),
  role: yup
    .string()
    .oneOf(['admin', 'team_leader', 'worker'], 'Please select a valid role')
    .required('Role is required'),
});
