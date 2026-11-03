# Contract status

Status: PRE-CONFORMANCE

contract/openapi.json is known to disagree with the server (for example the login response lacks the
{success, data, meta} envelope and the user object). Do not generate, or hand-write, API models from it.
It becomes CONFORMANT after the backend's contract-conformance package merges and this script is rerun.

Last synced from the backend at commit 91f1069e9afb484778f373937878f30606ab2073 (decisions revision 19) on 2026-11-03T01:46:57Z.
