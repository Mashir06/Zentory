// Configuración de Firebase del panel (proyecto zentory-base).
//
// Por ahora usa los datos de la app Android. Si el inicio de sesión falla con
// un error de "API key" o "referer", registra una app web en Firebase
// (Configuración del proyecto > Tus apps > Agregar app > Web) y reemplaza
// este objeto por el que te muestra Firebase.
export const firebaseConfig = {
  apiKey: 'AIzaSyBRRYtBVWeS_9e-kn-8dYUKVCtRqagJYSw',
  authDomain: 'zentory-base.firebaseapp.com',
  projectId: 'zentory-base',
  storageBucket: 'zentory-base.firebasestorage.app',
  messagingSenderId: '794054120945',
  appId: '1:794054120945:android:a50a962c8de657d7c8a050',
};

// Reglas de la suscripción (deben coincidir con la app y firestore.rules).
export const GRACE_DAYS = 5;
export const WARNING_DAYS = 5;
