/* Local placeholder. Overwritten deterministically by scripts/generate-build-identity.py. */
#if defined(__APPLE__)
__attribute__((used, section("__TEXT,__cjidentity")))
#else
__attribute__((used))
#endif
const char cangjie_build_identity_marker[] =
    "CANGJIE_IDENTITY_V1:eyJidWlsZCI6IjEiLCJidW5kbGVJZGVudGlmaWVyIjoiY29tLmp1eWFuZy5DYW5nSmllIiwiY2FuZGlkYXRlU2V0SUQiOiJsb2NhbCIsImNvbW1pdCI6ImxvY2FsIiwiZmluZ2VycHJpbnQiOiJsb2NhbCIsInJvbGUiOiJtYWluIiwic2NoZW1hVmVyc2lvbiI6MSwidmVyc2lvbiI6IjEuMCIsInZpc2libGVDb21taXQiOiJsb2NhbCJ9";
