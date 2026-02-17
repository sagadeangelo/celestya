python3 - <<'PY'
import sqlite3
import os

DB_PATH = '/data/celestya.db'

# Lista de archivos que esperamos haber subido (basado en lo que vimos en tu carpeta local)
# El script asignará la key 'uploads/testers/<filename>' al usuario cuyo email coincida con el nombre.
FILES = [
    "tester_female_01@celestya.test.png",
    "tester_female_02@celestya.test.png",
    "tester_female_03@celestya.test.png",
    "tester_female_04@celestya.test.png",
    "tester_female_05@celestya.test.png",
    "tester_female_06@celestya.test.png",
    "tester_female_07@celestya.test.png",
    "tester_female_08@celestya.test.png",
    "tester_female_09@celestya.test.png",
    "tester_female_10@celestya.test.png"
]

print(f"Connecting to database at {DB_PATH}...")
try:
    con = sqlite3.connect(DB_PATH)
    cur = con.cursor()
    
    updated_count = 0
    not_found = []

    for filename in FILES:
        # Extraer email (todo antes de la extensión .png/.jpg)
        email = os.path.splitext(filename)[0]
        # Construir la key de R2
        r2_key = f"uploads/testers/{filename}"
        
        # Verificar si el usuario existe
        cur.execute("SELECT id FROM users WHERE email = ?", (email,))
        row = cur.fetchone()
        
        if row:
            print(f"UPDATING {email} -> {r2_key}")
            cur.execute("UPDATE users SET profile_photo_key = ? WHERE email = ?", (r2_key, email))
            updated_count += 1
        else:
            print(f"NOT FOUND: User with email {email} not in DB.")
            not_found.append(email)

    con.commit()
    print("-" * 30)
    print(f"RESUMEN: {updated_count} usuarios actualizados.")
    if not_found:
        print(f"NO ENCONTRADOS ({len(not_found)}): {', '.join(not_found)}")
    
    print("-" * 30)
    print("VERIFICACION (Muestra):")
    cur.execute("SELECT email, profile_photo_key FROM users WHERE email LIKE 'tester_female_%' ORDER BY email LIMIT 5")
    for r in cur.fetchall():
        print(f"{r[0]}: {r[1]}")

    con.close()

except Exception as e:
    print(f"CRITICAL ERROR: {e}")
PY
