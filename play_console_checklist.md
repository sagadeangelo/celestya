# Celestya: Google Play Console Checklist

Este documento centraliza los requisitos y datos necesarios para la publicación en Google Play.

## 1. Store Listing (Ficha de Play Store)

### Texto
- [ ] **Título**: Celestya
- [ ] **Descripción corta**: Encuentra conexiones auténticas basadas en compatibilidad y fe.
- [ ] **Descripción larga**:
  Celestya es la aplicación de citas diseñada para ayudarte a encontrar una pareja con la que compartas valores y metas.
  
  Características principales:
  - Cuestionario de compatibilidad único.
  - Perfiles detallados con ubicación y biografía.
  - Intro de voz para conexiones más humanas.
  - Sistema de matches y chat seguro.
  
  Únete a nuestra comunidad y encuentra a alguien especial hoy mismo.

### Activos
- [ ] **Icono (512x512)**: `assets/icons/icon_512.png`
- [ ] **Feature Graphic (1024x500)**: [POR GENERAR]
- [ ] **Screenshots (2-8)**: [POR GENERAR - Teléfono, Tablet]

### Clasificación
- [ ] **Categoría**: Estilo de vida / Citas
- [ ] **Tags**: Dating, Relationship, Social, LDS.

---

## 2. Play Console - App Access (Instrucciones para Revisores)

Para asegurar que los revisores de Google puedan probar toda la funcionalidad:

### Pasos para el Revisor:
1. **Instalación**: Iniciar la app desde una instalación limpia.
2. **Splash/Landing**: Esperar la animación de carga.
3. **Login**: Introducir las credenciales demo proporcionadas abajo.
4. **Discover**: Al entrar, se muestra el radar de búsqueda. Tocar el corazón central para ir a "Matches".
5. **Matches**: Deslizar (Swipe) para ver candidatos.
6. **Chat**: Si hay un match, ir a la pestaña "Chats" para probar la mensajería.
7. **Perfil**: Visitar la cuarta pestaña para ver o editar datos personales.

### Credenciales de Prueba:
- **Usuario**: `demo@celestya.app`
- **Contraseña**: `Celestya2024!` (Ejemplo placeholder)
- **Nota**: Si la cuenta no existe, el revisor puede usar "Crear cuenta" con cualquier correo `@test.com`.

---

## 3. Policy / UGC / Dating Compliance

### Medidas de Seguridad Obligatorias:
- [ ] **Reportar/Bloquear**: Botones visibles en:
  - Perfil del usuario (icono de advertencia/escudo).
  - Dentro de la ventana de Chat (menú superior).
- [ ] **Regla de Bloqueo**: Una vez bloqueado, el usuario desaparece de:
  - Discovery Feed.
  - Lista de Matches.
  - Inbox de Chats.
- [ ] **Moderación**: Existe un backend para procesar reportes y banear usuarios malintencionados.

### Texto "Cómo reportar" (Para el formulario de Play Console):
> "Los usuarios pueden reportar comportamiento inapropiado tocando el icono de advertencia en el perfil de cualquier match o dentro de la conversación de chat. Celestya revisa todos los reportes en menos de 24 horas y aplica bloqueos definitivos a infractores de nuestras políticas."

---

## 4. Data Safety / Privacy Alignment

### Tabla de Recolección de Datos:
| Tipo de Datos | Propósito | Compartido | Encriptado | Opcional |
| :--- | :--- | :--- | :--- | :--- |
| **Email** | Autenticación / Cuenta | No | Sí (AES/HTTPS) | No |
| **Fotos (UGC)** | Visualización de Perfil | No | Sí | No |
| **Bio / Intereses** | Personalización del Perfil | No | Sí | Sí |
| **Ubicación** | Proximal (Ciudad/Estado) | No | Sí | Sí (JIT) |
| **Audio (Intro)** | Perfil Multimedia | No | Sí | Sí |
| **IDs (Device/User)** | Funcionalidad de la App | No | Sí | No |
| **Logs / Crashes** | Análisis y Estabilidad | No | Sí | No |

### Detalles Técnicos:
- **Ubicación**: Es **aproximada** (basada en ciudad) y se usa para el emparejamiento. No se rastrea en tiempo real ni en segundo plano.
- **Terceros**: 
  - **Fly.io**: Hosting del Backend (infraestructura segura).
  - **Cloudflare R2**: Almacenamiento cifrado de archivos multimedia.
- **Borrado**: El usuario garantiza la eliminación TOTAL (Archivos en R2 + Records en DB) mediante el botón "Eliminar mi cuenta".

---

## 5. Release QA (Protocolo de Lanzamiento)

### Proceso de Validación:
1. **Build**: Generar AAB firmado con `key.properties`.
2. **Closed Testing**: Subir a la pista de "Testing cerrado" en Play Console.
3. **Smoke Test**: Validar en dispositivos físicos (Android 10, 11, 13, 14):
   - Flujo Completo: Registro -> Autodetección de Ciudad -> Subida de Fotos -> Swipe -> Match -> Chat -> Borrar Cuenta.
4. **Versioning**: Asegurar `versionCode` incremental y `versionName` semántico (ej: `1.0.1`).

---

## 6. Firma de Producción (Configuración)

### Pasos Técnicos:
1. Generar Keystore:
   `keytool -genkey -v -keystore release.keystore -alias celestya -keyalg RSA -keysize 2048 -validity 10000`
2. Guardar en `android/app/release.keystore` (Añadir a `.gitignore`).
3. Crear `android/key.properties` basado en `key.properties.template`.

### Comandos Finales:
- `flutter clean && flutter pub get`
- `flutter pub run flutter_launcher_icons:main`
- `flutter build appbundle --release`
