import { BrowserRouter } from 'react-router-dom'

import { AuthProvider } from '../core/auth/AuthContext'
import { AppRouter } from './AppRouter'

function App() {
  return (
    <AuthProvider>
      <BrowserRouter>
        <AppRouter />
      </BrowserRouter>
    </AuthProvider>
  )
}

export default App
