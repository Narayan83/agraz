import React, { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { Lock, Mail, ArrowRight, ArrowLeft, Loader2, KeyRound } from 'lucide-react';
import {
  login as loginUser,
  forgotPassword,
  verifyResetCode,
  resetPasswordWithCode,
} from '../api/api';
import './Login.css';

const Login = () => {
  const [mode, setMode] = useState('login');
  const [step, setStep] = useState(0);
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [code, setCode] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [error, setError] = useState('');
  const [info, setInfo] = useState('');
  const [loading, setLoading] = useState(false);
  const navigate = useNavigate();

  const resetForgotState = () => {
    setStep(0);
    setCode('');
    setNewPassword('');
    setConfirmPassword('');
    setError('');
    setInfo('');
  };

  const handleLogin = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError('');

    try {
      const data = await loginUser(email.trim(), password);
      localStorage.setItem('token', data.token);
      localStorage.setItem('user', JSON.stringify(data.user));
      navigate('/home');
    } catch (err) {
      setError(err.response?.data?.message || 'Login failed. Please check your credentials.');
    } finally {
      setLoading(false);
    }
  };

  const handleForgot = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError('');
    setInfo('');
    try {
      if (step === 0) {
        const data = await forgotPassword(email.trim());
        setInfo(data.message || 'A 6-digit code was sent to your email.');
        setStep(1);
      } else if (step === 1) {
        const data = await verifyResetCode(email.trim(), code.trim());
        setInfo(data.message || 'Code verified. Set a new password.');
        setStep(2);
      } else {
        if (newPassword.length < 6) {
          setError('New password must be at least 6 characters');
          return;
        }
        if (newPassword !== confirmPassword) {
          setError('Passwords do not match');
          return;
        }
        const data = await resetPasswordWithCode(
          email.trim(),
          code.trim(),
          newPassword,
          confirmPassword
        );
        setMode('login');
        resetForgotState();
        setPassword('');
        setInfo(data.message || 'Password reset successfully. You can sign in now.');
      }
    } catch (err) {
      setError(
        err.response?.data?.error ||
          err.response?.data?.message ||
          'Request failed. Please try again.'
      );
    } finally {
      setLoading(false);
    }
  };

  const heading =
    mode === 'login'
      ? { title: 'Welcome Back', subtitle: 'Sign in to access your RBAC Dashboard' }
      : step === 0
        ? { title: 'Forgot password', subtitle: 'We will email a 6-digit code to reset your password.' }
        : step === 1
          ? { title: 'Enter code', subtitle: `Enter the 6-digit code sent to ${email.trim()}` }
          : { title: 'New password', subtitle: 'Code verified. Choose a new password.' };

  const submitLabel =
    mode === 'login'
      ? 'Sign In'
      : step === 0
        ? 'Send code'
        : step === 1
          ? 'Verify code'
          : 'Reset password';

  return (
    <div className="login-page">
      <div className="login-card">
        <div className="login-header">
          <div className="login-logo">RB</div>
          <h1>{heading.title}</h1>
          <p>{heading.subtitle}</p>
        </div>

        <form onSubmit={mode === 'login' ? handleLogin : handleForgot} className="login-form">
          {error && <div className="login-error">{error}</div>}
          {info && !error && <div className="login-info">{info}</div>}

          <div className="form-group">
            <label>Email Address</label>
            <div className="input-with-icon">
              <Mail size={18} />
              <input
                type="email"
                placeholder="Enter your email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                required
                disabled={mode === 'forgot' && step > 0}
                autoComplete="email"
              />
            </div>
          </div>

          {mode === 'login' && (
            <div className="form-group">
              <label>Password</label>
              <div className="input-with-icon">
                <Lock size={18} />
                <input
                  type="password"
                  placeholder="Enter your password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  required
                />
              </div>
            </div>
          )}

          {mode === 'forgot' && step >= 1 && (
            <div className="form-group">
              <label>Verification code</label>
              <div className="input-with-icon">
                <KeyRound size={18} />
                <input
                  type="text"
                  inputMode="numeric"
                  maxLength={6}
                  placeholder="6-digit code"
                  value={code}
                  onChange={(e) => setCode(e.target.value.replace(/\D/g, '').slice(0, 6))}
                  required
                  disabled={step > 1}
                />
              </div>
            </div>
          )}

          {mode === 'forgot' && step >= 2 && (
            <>
              <div className="form-group">
                <label>New password</label>
                <div className="input-with-icon">
                  <Lock size={18} />
                  <input
                    type="password"
                    placeholder="At least 6 characters"
                    value={newPassword}
                    onChange={(e) => setNewPassword(e.target.value)}
                    required
                    minLength={6}
                  />
                </div>
              </div>
              <div className="form-group">
                <label>Confirm password</label>
                <div className="input-with-icon">
                  <Lock size={18} />
                  <input
                    type="password"
                    placeholder="Re-enter new password"
                    value={confirmPassword}
                    onChange={(e) => setConfirmPassword(e.target.value)}
                    required
                    minLength={6}
                  />
                </div>
              </div>
            </>
          )}

          {mode === 'login' && (
            <div className="login-forgot-row">
              <button
                type="button"
                className="login-forgot-link"
                onClick={() => {
                  setMode('forgot');
                  resetForgotState();
                }}
              >
                Forgot password?
              </button>
            </div>
          )}

          <button type="submit" className="login-submit" disabled={loading}>
            {loading ? (
              <Loader2 className="spinner" size={20} />
            ) : (
              <>
                {submitLabel} <ArrowRight size={20} />
              </>
            )}
          </button>

          {mode === 'forgot' && (
            <button
              type="button"
              className="login-back-link"
              onClick={() => {
                if (step === 1) {
                  setStep(0);
                  setError('');
                  setInfo('');
                  return;
                }
                setMode('login');
                resetForgotState();
              }}
            >
              <ArrowLeft size={16} />
              {step === 1 ? 'Use a different email' : 'Back to sign in'}
            </button>
          )}
        </form>

        <div className="login-footer">
          <p>
            Register a business without signing in:{' '}
            <Link to="/register-service">Service registration</Link>
          </p>
          <p>Platform admin: <b>admin@admin.com</b> / <b>admin123</b></p>
          <p>Sample vendor: <b>vendor@admin.com</b> / <b>admin123</b></p>
        </div>
      </div>
    </div>
  );
};

export default Login;
