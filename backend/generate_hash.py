"""
Script untuk generate password hash admin.
Jalankan: python generate_hash.py
"""

from passlib.context import CryptContext

pwd_context = CryptContext(
    schemes=["bcrypt_sha256", "bcrypt"],
    deprecated="auto",
)

def generate_hash(password: str) -> str:
    return pwd_context.hash(password, scheme="bcrypt_sha256")


if __name__ == "__main__":
    print("=== Generate Password Hash untuk Admin ===\n")
    
    nip = input("Masukkan NIP admin (18 digit): ").strip()
    
    if len(nip) != 18 or not nip.isdigit():
        print("ERROR: NIP harus 18 digit angka!")
        exit(1)
    
    nama = input("Masukkan nama admin: ").strip()
    
    # Password default = NIP itu sendiri
    password = nip
    hashed = generate_hash(password)
    
    print("\n=== Jalankan SQL ini di Supabase SQL Editor ===\n")
    print(f"""INSERT INTO users (name, nip, role, password, created_at)
VALUES (
  '{nama}',
  '{nip}',
  'admin',
  '{hashed}',
  NOW()
);""")
    
    print("\n=== Info Login Admin ===")
    print(f"NIP    : {nip}")
    print(f"Password default : {nip} (sama dengan NIP)")
    print("\nJangan lupa ganti password setelah login pertama!")