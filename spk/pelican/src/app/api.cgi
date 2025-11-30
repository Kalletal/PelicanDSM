#!/bin/sh
# CGI proxy for Wings API - forwards requests to the loading-proxy on port 8080

# Handle CORS preflight
if [ "$REQUEST_METHOD" = "OPTIONS" ]; then
    echo "Content-Type: application/json"
    echo "Access-Control-Allow-Origin: *"
    echo "Access-Control-Allow-Methods: GET, POST, OPTIONS"
    echo "Access-Control-Allow-Headers: Content-Type"
    echo ""
    exit 0
fi

# Get the action from query string
ACTION=$(echo "$QUERY_STRING" | sed -n 's/.*action=\([^&]*\).*/\1/p')

# Set content type and CORS headers
echo "Content-Type: application/json"
echo "Access-Control-Allow-Origin: *"
echo ""

case "$ACTION" in
    status)
        curl -s "http://127.0.0.1:8080/api/wings/status" 2>/dev/null || echo '{"success":false,"error":"Service unavailable"}'
        ;;
    get-config)
        curl -s "http://127.0.0.1:8080/api/wings/config" 2>/dev/null || echo '{"success":false,"error":"Service unavailable"}'
        ;;
    save-config)
        # Read POST data
        if [ "$REQUEST_METHOD" = "POST" ]; then
            read -n "$CONTENT_LENGTH" POST_DATA
            curl -s -X POST -H "Content-Type: application/json" -d "$POST_DATA" "http://127.0.0.1:8080/api/wings/config" 2>/dev/null || echo '{"success":false,"error":"Service unavailable"}'
        else
            echo '{"success":false,"error":"POST method required"}'
        fi
        ;;
    *)
        echo '{"success":false,"error":"Unknown action"}'
        ;;
esac
