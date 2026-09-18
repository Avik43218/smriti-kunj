"""Pure-logic tests for the email-OTP second factor. No DB/network needed —
the request/verify *endpoints* touch Mongo and are exercised by
integration tests instead."""
from app.core.otp import generate_otp, hash_otp, verify_otp_code


def test_generate_otp_default_length_and_charset():
    code = generate_otp()
    assert len(code) == 6
    assert code.isdigit()


def test_generate_otp_respects_custom_length():
    assert len(generate_otp(length=4)) == 4


def test_hash_otp_does_not_store_plaintext():
    hashed = hash_otp("123456")
    assert hashed != "123456"
    assert len(hashed) == 64  # sha256 hex digest


def test_verify_otp_code_accepts_correct_and_rejects_wrong():
    hashed = hash_otp("482913")
    assert verify_otp_code("482913", hashed) is True
    assert verify_otp_code("000000", hashed) is False


def test_hash_otp_is_deterministic_for_same_code():
    assert hash_otp("111111") == hash_otp("111111")
