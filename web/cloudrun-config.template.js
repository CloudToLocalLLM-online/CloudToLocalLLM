// CloudToLocalLLM - Cloud Run Configuration (Template)
// This template is rendered at runtime by docker-entrypoint-web.sh using envsubst

window.cloudRunConfig = {
  // GCIP/GIS configuration injected by environment
  gcipApiKey: "${GCIP_API_KEY}",
};

