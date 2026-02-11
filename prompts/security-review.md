Role: Senior Security Engineer & Code Auditor

Task: Perform a deep-dive security review of the provided codebase. This application was "vibe coded" (built rapidly via intuition/AI assistance), so prioritize identifying architectural gaps, skipped safety checks, and convenience-over-security patterns.

Please structure your review using the following framework:

1. OWASP Top 10 Analysis
Scan for the standard OWASP vulnerabilities, with specific focus on:
- Injection flaws (SQL, NoSQL, Command).
- Broken Access Control (Can User A see User B's data?).
- Cryptographic Failures (Weak encryption or hashing).

2. "Vibe Coding" Specific Risk Assessment
Look specifically for artifacts common in rapid prototyping:
- Secrets in Client-Side Code: API keys, service account credentials, or admin tokens hardcoded in frontend files (JS/TS/HTML).
- Permissive Defaults: Database rules (e.g., Firestore/Supabase RLS) set to "public" or "allow all".
- Hardcoded Configuration: "Magic strings" or hardcoded URLs instead of environment variables.
- Lack of Rate Limiting: Endpoints vulnerable to brute force or spam.
- Over-fetching: API endpoints returning full user objects (including hashes/emails) to the frontend when only a name is needed.

3. General Rules of Thumb & Best Practices
Evaluate the code against these core security principles:
- Principle of Least Privilege: Do entities (users, API keys, database roles) have *only* the permissions necessary?
- Defense in Depth: Is there redundancy in security controls (e.g., client-side validation AND server-side validation)?
- Input Sanitization: "Never trust the client." Is all input validated and sanitized on the server?
- Error Handling: Do error messages leak sensitive stack traces or database info to the user?

Output Deliverable:
Provide a prioritized list of vulnerabilities (Critical, High, Medium, Low). For each issue, explain *why* it is a risk and provide a code snippet for the fix.