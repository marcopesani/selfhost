# Cost guard

A 2× RTX PRO 6000 or 4× H200 pod bills by the second while running. The network volume bills monthly whether or not a pod is up.

Rules:

- Experimental pods get `--terminate-after` unless the user says keep warm.
- End of sitting: stop or delete the pod. Keep the volume.
- Do not set serverless `workers-min 1` (we are not using serverless).
- Confirm GPU hourly rate from `runpodctl gpu list` before create; do not guess.
