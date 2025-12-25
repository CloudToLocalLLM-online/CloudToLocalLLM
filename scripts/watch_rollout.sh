#!/bin/bash
set -e

NAMESPACE=$1
TYPE=$2
NAME=$3
TIMEOUT=${4:-300}

echo "Monitoring rollout of $TYPE/$NAME in $NAMESPACE with fail-fast on restarts..."

END=$((SECONDS+TIMEOUT))

while [ $SECONDS -lt $END ]; do
    # Check rollout status
    if kubectl rollout status "$TYPE/$NAME" -n "$NAMESPACE" --timeout=1s >/dev/null 2>&1; then
        echo "âœ… $TYPE/$NAME successfully rolled out."
        exit 0
    fi

    # Check for restarts on non-terminating pods
    # We assume label app=$NAME matches the selector.
    PODS=$(kubectl get pods -n "$NAMESPACE" -l app="$NAME" --no-headers | grep -v "Terminating" | awk '{print $1}')
    
    if [ -n "$PODS" ]; then
        for POD in $PODS; do
            # Get restart count for this pod
            # Use safe navigation in awk in case of empty input
            RESTARTS=$(kubectl get pod "$POD" -n "$NAMESPACE" -o jsonpath='{.status.containerStatuses[*].restartCount}' 2>/dev/null | awk '{s+=$1} END {print s}')
            
            if [ "${RESTARTS:-0}" -gt 3 ]; then
                echo "âŒ Detected ${RESTARTS} restarts for pod $POD! Fail fast triggered (limit 3)."
                
                echo "--- Pod Status ---"
                kubectl get pod "$POD" -n "$NAMESPACE"
                
                echo "--- Logs (tail 50) ---"
                kubectl logs "$POD" -n "$NAMESPACE" --tail=50 --all-containers=true --prefix || true
                
                exit 1
            elif [ "${RESTARTS:-0}" -gt 0 ]; then
                echo "âš ï¸ Detected ${RESTARTS} restarts for pod $POD. Monitoring..."
            fi
        done
    fi
    
    sleep 5
done

echo "âŒ Timeout waiting for rollout of $TYPE/$NAME"
exit 1
