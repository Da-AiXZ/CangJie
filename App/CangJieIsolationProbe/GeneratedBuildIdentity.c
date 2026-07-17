/* Local placeholder. Overwritten deterministically by scripts/generate-build-identity.py. */
#if defined(__APPLE__)
__attribute__((used, section("__TEXT,__cjidentity")))
#else
__attribute__((used))
#endif
const char cangjie_build_identity_marker[] =
    "CANGJIE_IDENTITY_V1:eyJidWlsZCI6IjEiLCJidW5kbGVJZGVudGlmaWVyIjoiY29tLmp1eWFuZy5DYW5nSmllLktleWNoYWluSXNvbGF0aW9uUHJvYmUiLCJjYW5kaWRhdGVTZXRJRCI6ImxvY2FsIiwiY29tbWl0IjoibG9jYWwiLCJmaW5nZXJwcmludCI6ImxvY2FsIiwicm9sZSI6ImtleWNoYWluSXNvbGF0aW9uUHJvYmUiLCJzY2hlbWFWZXJzaW9uIjoxLCJ2ZXJzaW9uIjoiMS4wIiwidmlzaWJsZUNvbW1pdCI6ImxvY2FsIn0";
