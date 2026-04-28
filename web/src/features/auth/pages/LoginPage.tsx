import { type FormEvent, useMemo, useState } from 'react'
import { useLocation, useNavigate } from 'react-router-dom'

import { useAuth } from '../../../core/auth/useAuth'

interface RouteState {
  from?: {
    pathname?: string
  }
}

type AuthTab = 'login' | 'register'

function getErrorMessage(error: unknown): string {
  if (error instanceof Error && error.message.trim().length > 0) {
    return error.message
  }
  return 'Operation impossible.'
}

function isValidEmail(value: string): boolean {
  return value.includes('@') && value.includes('.')
}

export function LoginPage() {
  const navigate = useNavigate()
  const location = useLocation()
  const { login, registerDoctor, isLoading } = useAuth()

  const [activeTab, setActiveTab] = useState<AuthTab>('login')

  const [cin, setCin] = useState('')
  const [password, setPassword] = useState('')
  const [loginError, setLoginError] = useState<string | null>(null)
  const [isLoginSubmitting, setIsLoginSubmitting] = useState(false)

  const [firstName, setFirstName] = useState('')
  const [lastName, setLastName] = useState('')
  const [registerCin, setRegisterCin] = useState('')
  const [email, setEmail] = useState('')
  const [registerPassword, setRegisterPassword] = useState('')
  const [confirmPassword, setConfirmPassword] = useState('')
  const [registerError, setRegisterError] = useState<string | null>(null)
  const [registerSuccess, setRegisterSuccess] = useState<string | null>(null)
  const [isRegisterSubmitting, setIsRegisterSubmitting] = useState(false)

  const redirectPath = useMemo(() => {
    const state = location.state as RouteState | null
    return state?.from?.pathname || '/dashboard'
  }, [location.state])

  async function handleLoginSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setLoginError(null)
    setRegisterSuccess(null)

    if (!cin.trim() || !password.trim()) {
      setLoginError('Veuillez remplir tous les champs obligatoires.')
      return
    }

    if (cin.trim().length < 3) {
      setLoginError('CIN invalide.')
      return
    }

    setIsLoginSubmitting(true)
    try {
      await login(cin.trim(), password)
      navigate(redirectPath, { replace: true })
    } catch (submitError) {
      setLoginError(getErrorMessage(submitError))
    } finally {
      setIsLoginSubmitting(false)
    }
  }

  async function handleRegisterSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setRegisterError(null)
    setRegisterSuccess(null)

    if (
      !firstName.trim() ||
      !lastName.trim() ||
      !registerCin.trim() ||
      !email.trim() ||
      !registerPassword ||
      !confirmPassword
    ) {
      setRegisterError('Veuillez remplir tous les champs obligatoires.')
      return
    }

    if (registerCin.trim().length < 3) {
      setRegisterError('CIN invalide.')
      return
    }

    if (!isValidEmail(email.trim())) {
      setRegisterError('Email invalide.')
      return
    }

    if (registerPassword.length < 6) {
      setRegisterError('Mot de passe: minimum 6 caracteres.')
      return
    }

    if (registerPassword !== confirmPassword) {
      setRegisterError('Les mots de passe ne correspondent pas.')
      return
    }

    setIsRegisterSubmitting(true)
    try {
      const result = await registerDoctor({
        first_name: firstName.trim(),
        last_name: lastName.trim(),
        cin: registerCin.trim(),
        email: email.trim(),
        password: registerPassword,
      })

      if (result.loggedIn) {
        navigate(redirectPath, { replace: true })
        return
      }

      setRegisterSuccess('Compte cree avec succes. Connectez-vous pour continuer.')
      setActiveTab('login')
      setCin(registerCin.trim())
      setPassword('')
    } catch (submitError) {
      setRegisterError(getErrorMessage(submitError))
    } finally {
      setIsRegisterSubmitting(false)
    }
  }

  const isSubmitting = isLoading || isLoginSubmitting || isRegisterSubmitting

  return (
    <main className="auth-page">
      <section className="auth-panel">
        <header className="auth-panel-header">
          <h1>Authentification</h1>
          <p>
            Login via CIN uniquement. Le role est detecte automatiquement a la
            connexion.
          </p>
        </header>

        <div className="auth-tab-row">
          <button
            className={activeTab === 'login' ? 'auth-tab is-active' : 'auth-tab'}
            onClick={() => setActiveTab('login')}
            type="button"
          >
            Se connecter
          </button>
          <button
            className={activeTab === 'register' ? 'auth-tab is-active' : 'auth-tab'}
            onClick={() => setActiveTab('register')}
            type="button"
          >
            Creer un compte
          </button>
        </div>

        {activeTab === 'login' && (
          <section className="section-card auth-form-card">
            <div className="section-card-header">
              <h3>Se connecter</h3>
            </div>

            <div className="section-card-body">
              <form className="auth-form" onSubmit={handleLoginSubmit}>
                <label className="field-block">
                  <span>CIN</span>
                  <input
                    autoComplete="username"
                    name="cin"
                    onChange={(event) => setCin(event.target.value)}
                    placeholder="Entrez votre CIN"
                    type="text"
                    value={cin}
                  />
                </label>

                <label className="field-block">
                  <span>Mot de passe</span>
                  <input
                    autoComplete="current-password"
                    name="password"
                    onChange={(event) => setPassword(event.target.value)}
                    placeholder="Entrez votre mot de passe"
                    type="password"
                    value={password}
                  />
                </label>

                {registerSuccess && (
                  <div className="feedback-banner is-success" role="status">
                    {registerSuccess}
                  </div>
                )}

                {loginError && (
                  <div className="error-banner" role="alert">
                    <p>{loginError}</p>
                  </div>
                )}

                <button
                  className="btn btn-primary auth-submit"
                  disabled={isSubmitting}
                  type="submit"
                >
                  {isLoginSubmitting ? 'Connexion...' : 'Se connecter'}
                </button>
              </form>
            </div>
          </section>
        )}

        {activeTab === 'register' && (
          <section className="section-card auth-form-card">
            <div className="section-card-header">
              <h3>Creer un compte medecin</h3>
            </div>

            <div className="section-card-body">
              <form className="auth-form" onSubmit={handleRegisterSubmit}>
                <label className="field-block">
                  <span>Prenom</span>
                  <input
                    autoComplete="given-name"
                    onChange={(event) => setFirstName(event.target.value)}
                    placeholder="Prenom"
                    type="text"
                    value={firstName}
                  />
                </label>

                <label className="field-block">
                  <span>Nom</span>
                  <input
                    autoComplete="family-name"
                    onChange={(event) => setLastName(event.target.value)}
                    placeholder="Nom"
                    type="text"
                    value={lastName}
                  />
                </label>

                <label className="field-block">
                  <span>CIN</span>
                  <input
                    autoComplete="off"
                    onChange={(event) => setRegisterCin(event.target.value)}
                    placeholder="CIN"
                    type="text"
                    value={registerCin}
                  />
                </label>

                <label className="field-block">
                  <span>Email</span>
                  <input
                    autoComplete="email"
                    onChange={(event) => setEmail(event.target.value)}
                    placeholder="email@exemple.com"
                    type="email"
                    value={email}
                  />
                </label>

                <label className="field-block">
                  <span>Mot de passe</span>
                  <input
                    autoComplete="new-password"
                    onChange={(event) => setRegisterPassword(event.target.value)}
                    placeholder="Minimum 6 caracteres"
                    type="password"
                    value={registerPassword}
                  />
                </label>

                <label className="field-block">
                  <span>Confirmer mot de passe</span>
                  <input
                    autoComplete="new-password"
                    onChange={(event) => setConfirmPassword(event.target.value)}
                    placeholder="Confirmer mot de passe"
                    type="password"
                    value={confirmPassword}
                  />
                </label>

                {registerError && (
                  <div className="error-banner" role="alert">
                    <p>{registerError}</p>
                  </div>
                )}

                <button
                  className="btn btn-primary auth-submit"
                  disabled={isSubmitting}
                  type="submit"
                >
                  {isRegisterSubmitting ? 'Creation...' : 'Creer le compte'}
                </button>
              </form>
            </div>
          </section>
        )}
      </section>
    </main>
  )
}
