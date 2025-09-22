import otlpExporterPkg from '@opentelemetry/exporter-trace-otlp-http';
import resourcesPkg from '@opentelemetry/resources';
import semanticPkg from '@opentelemetry/semantic-conventions';
import traceBasePkg from '@opentelemetry/sdk-trace-base';
import sdkNodePkg from '@opentelemetry/sdk-node';
import autoInstPkg from '@opentelemetry/auto-instrumentations-node';

const { OTLPTraceExporter } = otlpExporterPkg;
const { Resource } = resourcesPkg;
const { SemanticResourceAttributes } = semanticPkg;
const { SimpleSpanProcessor } = traceBasePkg;
const { NodeSDK } = sdkNodePkg;
const { getNodeAutoInstrumentations } = autoInstPkg;

const sdk = new NodeSDK({
  resource: new Resource({
    [SemanticResourceAttributes.SERVICE_NAME]: 'api-backend',
  }),
  spanProcessor: new SimpleSpanProcessor(new OTLPTraceExporter()),
  instrumentations: [getNodeAutoInstrumentations()],
});

sdk.start();
