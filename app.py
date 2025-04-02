import os
import json
import time
import socket
import logging
import datetime
import threading
import random
import psutil
from faker import Faker
from flask import Flask, request, render_template, jsonify

app = Flask(__name__)
fake = Faker()

# Simple TCP socket sender


def send_log_to_logstash(log_data):
    try:
        # Try to connect to logstash, if it fails, just log the error
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(1)  # Add timeout to prevent hanging
        if sock.connect_ex(('logstash', 5000)) == 0:
            log_json = json.dumps(log_data)
            sock.sendall((log_json + '\n').encode())
        sock.close()
    except Exception as e:
        print(f"Error sending log: {e}")


# Setup standard logging for console output
logger = logging.getLogger('flask-app')
logger.setLevel(logging.INFO)
console_handler = logging.StreamHandler()
console_handler.setFormatter(logging.Formatter(
    '%(asctime)s - %(name)s - %(levelname)s - %(message)s'))
logger.addHandler(console_handler)

# Flask routes


@app.route('/')
def home():
    username = request.args.get('username', 'anonymous')

    log_data = {
        'timestamp': datetime.datetime.now().isoformat(),
        'hostname': socket.gethostname(),
        'server_name': socket.gethostname(),
        'username': username,
        'app_name': 'flask-app',
        'container_id': 1,
        'log_level': 'INFO',
        'message': f"Home page accessed by {username}",
        'request_url': '/',
        'parameters': '',
        'path': '/',
        'method': request.method,
        'ip': request.remote_addr,
        'random_number': random.randint(1, 1000)
    }

    send_log_to_logstash(log_data)
    logger.info(f"Home page accessed by {username}")

    return render_template('index.html')


@app.route('/api/logs')
def get_logs():
    username = request.args.get('username', 'anonymous')
    count = int(request.args.get('count', 10))

    log_data = {
        'timestamp': datetime.datetime.now().isoformat(),
        'hostname': socket.gethostname(),
        'server_name': socket.gethostname(),
        'username': username,
        'app_name': 'flask-app',
        'container_id': 1,
        'log_level': 'INFO',
        'message': f"API logs accessed, requested {count} logs by {username}",
        'request_url': '/api/logs',
        'parameters': f'count={count}',
        'path': '/api/logs',
        'method': request.method,
        'ip': request.remote_addr,
        'random_number': random.randint(1, 1000)
    }

    send_log_to_logstash(log_data)
    logger.info(f"API logs accessed, requested {count} logs by {username}")

    # Simulate fetching logs
    logs = []
    for i in range(count):
        logs.append({
            'id': i,
            'timestamp': datetime.datetime.now().isoformat(),
            'message': fake.sentence(),
            'level': random.choice(['INFO', 'WARNING', 'ERROR'])
        })

    return jsonify(logs)


@app.route('/api/system')
def get_system_info():
    username = request.args.get('username', 'anonymous')

    log_data = {
        'timestamp': datetime.datetime.now().isoformat(),
        'hostname': socket.gethostname(),
        'server_name': socket.gethostname(),
        'username': username,
        'app_name': 'flask-app',
        'container_id': 1,
        'log_level': 'INFO',
        'message': f"System info requested by {username}",
        'request_url': '/api/system',
        'parameters': '',
        'path': '/api/system',
        'method': request.method,
        'ip': request.remote_addr,
        'random_number': random.randint(1, 1000)
    }

    send_log_to_logstash(log_data)
    logger.info(f"System info requested by {username}")

    # Generate system stats
    memory = psutil.virtual_memory()
    disk = psutil.disk_usage('/')

    system_info = {
        'cpu': psutil.cpu_percent(interval=0.1),
        'memory': {
            'total': memory.total,
            'available': memory.available,
            'percent': memory.percent
        },
        'disk': {
            'total': disk.total,
            'used': disk.used,
            'free': disk.free,
            'percent': disk.percent
        }
    }

    return jsonify(system_info)


@app.route('/error')
def trigger_error():
    username = request.args.get('username', 'anonymous')

    try:
        # Deliberately cause an exception
        result = 1 / 0
    except Exception as e:
        log_data = {
            'timestamp': datetime.datetime.now().isoformat(),
            'hostname': socket.gethostname(),
            'server_name': socket.gethostname(),
            'username': username,
            'app_name': 'flask-app',
            'container_id': 1,
            'log_level': 'ERROR',
            'message': f"Error occurred: {str(e)}",
            'request_url': '/error',
            'parameters': '',
            'path': '/error',
            'method': request.method,
            'ip': request.remote_addr,
            'random_number': random.randint(1, 1000)
        }

        send_log_to_logstash(log_data)
        logger.error(f"Error occurred: {str(e)}")

        return "Error logged! Check Kibana."


@app.route('/generate')
def start_generation():
    username = request.args.get('username', 'system')

    # Get generation parameters
    count = request.args.get('count')
    size_mb = request.args.get('size_mb')

    # Determine generation type and parameters
    if count is not None:
        target_count = int(count)
        generation_type = 'count'
    elif size_mb is not None:
        target_size = float(size_mb) * 1024 * 1024  # Convert MB to bytes
        generation_type = 'size'
    else:
        return "Please specify either count or size_mb parameter", 400

    log_data = {
        'timestamp': datetime.datetime.now().isoformat(),
        'hostname': socket.gethostname(),
        'server_name': socket.gethostname(),
        'username': username,
        'app_name': 'flask-app',
        'container_id': 1,
        'log_level': 'INFO',
        'message': f"Starting log generation by {username}",
        'request_url': '/generate',
        'parameters': f'type={generation_type}',
        'path': '/generate',
        'method': request.method,
        'ip': request.remote_addr,
        'random_number': random.randint(1, 1000)
    }

    send_log_to_logstash(log_data)
    logger.info(f"Starting log generation by {username}")

    # Start generation in a background thread
    thread = threading.Thread(target=generate_logs, args=(
        generation_type, target_size if 'size' in locals() else target_count))
    thread.daemon = True
    thread.start()

    return f"Started generating logs in the background. Check Kibana for progress."


def generate_logs(generation_type, target):
    """Generate logs based on specified type and target"""
    logger.info(
        f"Starting log generation (type: {generation_type}, target: {target})")

    # Track progress
    total_size = 0
    total_count = 0
    start_time = time.time()

    # Prepare log content options
    log_levels = ['INFO', 'DEBUG', 'ERROR', 'WARN', 'TRACE']
    usernames = [fake.user_name() for _ in range(100)]
    app_names = ["app1", "app2", "app3", "app4", "app5"]
    request_urls = ["/home", "/about", "/contact", "/faq", "/services"]
    parameters_options = ["param1=value1", "param2=value2",
                          "param3=value3", "param4=value4", "param5=value5"]
    http_methods = ['GET', 'POST', 'PUT', 'DELETE', 'PATCH']
    ips = [fake.ipv4() for _ in range(100)]

    try:
        while True:
            # Check if we've reached the target
            if generation_type == 'size' and total_size >= target:
                break
            elif generation_type == 'count' and total_count >= target:
                break

            # Generate a single log entry
            log_data = {
                'timestamp': datetime.datetime.now().isoformat(),
                'hostname': socket.gethostname(),
                'server_name': socket.gethostname(),
                'username': random.choice(usernames),
                'app_name': random.choice(app_names),
                'container_id': random.randint(1, 100),
                'log_level': random.choice(log_levels),
                'message': f"Generated log entry {total_count + 1}",
                'request_url': random.choice(request_urls),
                'parameters': random.choice(parameters_options),
                'path': random.choice(request_urls),
                'method': random.choice(http_methods),
                'ip': random.choice(ips),
                'random_number': random.randint(1, 1000)
            }

            # Convert log data to JSON string to calculate size
            log_json = json.dumps(log_data)
            log_size = len(log_json.encode('utf-8'))

            # Send log to logstash
            send_log_to_logstash(log_data)

            # Update counters
            total_size += log_size
            total_count += 1

            # Log progress every 100 entries
            if total_count % 100 == 0:
                elapsed_time = time.time() - start_time
                if generation_type == 'size':
                    logger.info(
                        f"Generated {total_count} logs, {total_size / (1024*1024):.2f}MB so far")
                else:
                    logger.info(f"Generated {total_count}/{target} logs")

        # Log completion
        elapsed_time = time.time() - start_time
        logger.info(
            f"Log generation completed. Generated {total_count} logs in {elapsed_time:.2f} seconds")

    except Exception as e:
        logger.error(f"Error during log generation: {str(e)}")


if __name__ == '__main__':
    # Start Flask app
    logger.info("Flask application starting")
    app.run(host='0.0.0.0', port=5000)
