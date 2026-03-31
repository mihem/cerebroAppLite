#!/bin/bash

# Configuration
IMAGE_NAME="cerebro-shiny-app"
SERVICE_NAME="shiny-app"

# Function definitions
function build_image() {
    echo "🏗️  Building Docker image..."
    docker-compose build
}

function rebuild_image() {
    echo "🏗️  Rebuilding Docker image (no cache)..."
    docker-compose build --no-cache
}

function start_app() {
    echo "🚀 Starting app..."
    # Ensure logs directory exists
    mkdir -p logs
    docker-compose up -d
    echo "✅ App started!"
    echo "   - URL: http://localhost:3838"
    echo "   - Logs: ./logs/ directory"
}

function stop_app() {
    echo "🛑 Stopping app..."
    docker-compose down
    echo "✅ App stopped."
}

function restart_app() {
    echo "🔄 Restarting app..."
    stop_app
    start_app
}

function view_logs() {
    echo "📜 Showing logs (Press Ctrl+C to exit)..."
    docker-compose logs -f
}

function enter_shell() {
    echo "💻 Entering container shell..."
    # Check if container is running first
    if [ -z "$(docker-compose ps -q $SERVICE_NAME)" ]; then
        echo "⚠️  Container is not running. Starting it first..."
        start_app
    fi
    docker-compose exec $SERVICE_NAME bash
}

function remove_image() {
    echo "🗑️  Removing image..."
    echo "   - Stopping containers..."
    docker-compose down -v
    echo "   - Removing image $IMAGE_NAME..."
    if [[ "$(docker images -q $IMAGE_NAME 2> /dev/null)" != "" ]]; then
        docker rmi $IMAGE_NAME
        echo "✅ Image removed."
    else
        echo "⚠️  Image $IMAGE_NAME not found."
    fi
}

function purge_all() {
    echo "🧹 Purging everything..."
    echo "   - Stopping containers..."
    docker-compose down -v
    echo "   - Removing image $IMAGE_NAME..."
    if [[ "$(docker images -q $IMAGE_NAME 2> /dev/null)" != "" ]]; then
        docker rmi $IMAGE_NAME
        echo "✅ Image removed."
    else
        echo "⚠️  Image $IMAGE_NAME not found."
    fi
    echo "   - Pruning build cache..."
    docker builder prune -f
    echo "✅ All cleaned up (image + cache)."
}

function run_local() {
    echo "🖥️  Running app locally with Rscript..."
    Rscript app.R
}

function show_status() {
    echo "📊 Container Status:"
    docker-compose ps
}

function show_help() {
    echo "Usage: ./run_app.sh [command]"
    echo ""
    echo "Commands:"
    echo "  build    - Build the Docker image"
    echo "  rebuild  - Rebuild the Docker image (no cache)"
    echo "  start    - Start the container (detached mode)"
    echo "  stop     - Stop the container"
    echo "  restart  - Restart the container"
    echo "  logs     - View container logs"
    echo "  shell    - Open a bash shell inside the container"
    echo "  local    - Run app locally with Rscript app.R"
    echo "  clean    - Stop container and remove image (keep cache)"
    echo "  purge    - Stop container, remove image and clear cache"
    echo "  status   - Show current status"
    echo "  help     - Show this help message"
}

function show_menu() {
    echo "========================================="
    echo "  🐳 Cerebro Shiny App Docker Manager"
    echo "========================================="
    echo "1. Build Image      (build)"
    echo "2. Rebuild Image    (rebuild, no cache)"
    echo "3. Start App        (start)"
    echo "4. Stop App         (stop)"
    echo "5. Restart App      (restart)"
    echo "6. View Logs        (logs)"
    echo "7. Shell into App   (shell)"
    echo "8. Run Locally      (local, Rscript app.R)"
    echo "9. Remove Image     (clean)"
    echo "0. Purge All        (purge, image + cache)"
    echo "s. Show Status      (status)"
    echo "q. Exit"
    echo "========================================="
    echo -n "Enter your choice: "
}

# Command line argument handling
if [ "$1" != "" ]; then
    case $1 in
        build)   build_image ;;
        rebuild) rebuild_image ;;
        start)   start_app ;;
        stop)    stop_app ;;
        restart) restart_app ;;
        logs)    view_logs ;;
        shell)   enter_shell ;;
        local)   run_local ;;
        clean)   remove_image ;;
        purge)   purge_all ;;
        status)  show_status ;;
        help)    show_help ;;
        *)       echo "Invalid command: $1"; show_help ;;
    esac
    exit 0
fi

# Interactive Menu (if no arguments provided)
while true; do
    show_menu
    read choice
    echo ""
    case $choice in
        1) build_image ;;
        2) rebuild_image ;;
        3) start_app ;;
        4) stop_app ;;
        5) restart_app ;;
        6) view_logs ;;
        7) enter_shell ;;
        8) run_local ;;
        9) remove_image ;;
        0) purge_all ;;
        s) show_status ;;
        q) echo "Bye! 👋"; exit 0 ;;
        *) echo "❌ Invalid option. Please try again." ;;
    esac
    echo ""
    echo "Press Enter to continue..."
    read
done
