# Cost guard

A 2× RTX PRO 6000 (config A, 200k), 4× RTX PRO 6000 (config B, 1M), or 4× H200 pod bills by the second while running. 4× is roughly 2× the GPU bill of 2× — do not create B for a single 200k stream. The network volume bills monthly whether or not a pod is up.

Rules:

- Experimental pods get `--terminate-after` unless the user says keep warm.
- End of sitting: stop or delete the pod. Keep the volume.
- Do not set serverless `workers-min 1` (we are not using serverless).
- Confirm GPU hourly rate from `runpodctl gpu list` before create; do not guess.
