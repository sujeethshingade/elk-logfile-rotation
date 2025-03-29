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
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.connect(('logstash', 5000))
        log_json = json.dumps(log_data)
        sock.sendall((log_json + '\n').encode())
        sock.close()
    except Exception as e:
        print(f"Error sending log: {e}")

# Wait for Logstash to be available
def wait_for_logstash():
    logstash_host = 'logstash'
    logstash_port = 5000

    print("Waiting for Logstash to be ready...")
    while True:
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
                s.settimeout(1)
                if s.connect_ex((logstash_host, logstash_port)) == 0:
                    print("Logstash is available!")
                    break
        except Exception:
            pass
        time.sleep(1)

# Setup standard logging for console output
logger = logging.getLogger('flask-app')
logger.setLevel(logging.INFO)
console_handler = logging.StreamHandler()
console_handler.setFormatter(logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s'))
logger.addHandler(console_handler)

# Log Generator
def generate_massive_logs(target_gb=10):
    """Generate logs until reaching approximately the target size in GB"""
    
    wait_for_logstash()  # Ensure logstash is ready
    
    logger.info(f"Starting massive log generation (target: {target_gb}GB)")

    # Track log size approximation (in bytes)
    total_size = 0
    target_size = target_gb * 1024 * 1024 * 1024  # Convert GB to bytes

    # Prepare log content options
    log_levels = ['INFO', 'DEBUG', 'ERROR', 'WARN', 'TRACE']
    usernames = [fake.user_name() for _ in range(100)]
    app_names = ["app1", "app2", "app3", "app4", "app5"]

    # URLs for request simulation - use the exact ones from the shell script
    request_urls = ["/home", "/about", "/contact", "/faq", "/services"]

    # Parameters for request simulation - use the exact ones from the shell script
    parameters_options = ["param1=value1", "param2=value2",
                          "param3=value3", "param4=value4", "param5=value5"]

    # Methods for API calls
    http_methods = ['GET', 'POST', 'PUT', 'DELETE', 'PATCH']

    # Predefined messages from the shell script
    log_messages = [
        "User login successful: username=johndoe",
        "Error connecting to database: host=127.0.0.1, port=5432, error=connection refused",
        "System reboot initiated by user admin",
        "Server outage detected at 12:30 PM, initiating failover procedure",
        "Security alert: suspicious activity detected from IP address 192.168.1.100",
        "Backup completed successfully: files=100, size=200GB",
        "System performance issue detected, high memory usage: usage=90%, process=mongod",
        "Incoming request: method=POST, path=/api/users, client=192.168.1.100",
        "Application error: message='null pointer exception', method=main(), class=App",
        "Cron job completed: name=cleanup, status=success, duration=10m"
    ]

    # IP addresses for variety
    ips = [fake.ipv4() for _ in range(100)]

    count = 0
    start_process_time = time.time()
    last_status_time = start_process_time

    try:
        while total_size < target_size:
            count += 1

            # Select random values for this log
            username = random.choice(usernames)
            app_name = random.choice(app_names)
            container_id = random.randint(1, 100)
            log_level = random.choice(log_levels)
            ip = random.choice(ips)
            request_url = random.choice(request_urls)
            parameters = random.choice(parameters_options)
            random_number = random.randint(1, 1000)
            message = random.choice(log_messages)
            method = random.choice(http_methods)

            # Create log data that exactly matches the shell script format
            log_data = {
                'timestamp': datetime.datetime.now().isoformat(),
                'hostname': socket.gethostname(),
                'server_name': socket.gethostname(),
                'username': username,
                'app_name': app_name,
                'container_id': container_id,
                'log_level': log_level,
                'message': message,
                'request_url': request_url,
                'parameters': parameters,
                'path': request_url,
                'method': method,
                'ip': ip,
                'random_number': random_number
            }

            # Send directly to logstash
            send_log_to_logstash(log_data)

            # Calculate log size
            log_size = len(json.dumps(log_data))
            total_size += log_size

            # Print status every 100,000 logs or every 5 seconds
            current_time = time.time()
            if count % 100000 == 0 or current_time - last_status_time > 5:
                elapsed = current_time - start_process_time
                gb_written = total_size / (1024 * 1024 * 1024)
                rate = count / elapsed if elapsed > 0 else 0
                percent_complete = (total_size / target_size) * 100

                logger.info(
                    f"Generated {count:,} logs ({gb_written:.2f} GB / {target_gb} GB - {percent_complete:.1f}%), "
                    f"rate: {rate:.0f} logs/sec"
                )
                last_status_time = current_time

            # To avoid overwhelming CPU, sleep occasionally
            if count % 10000 == 0:
                time.sleep(0.01)

    except Exception as e:
        logger.error(f"Error during log generation: {str(e)}")

    finally:
        elapsed = time.time() - start_process_time
        logger.info(
            f"Finished generating {count:,} logs ({total_size / (1024 * 1024 * 1024):.2f} GB) in {elapsed:.1f} seconds"
        )

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
    size_gb = float(request.args.get('size', 10))
    username = request.args.get('username', 'system')

    log_data = {
        'timestamp': datetime.datetime.now().isoformat(),
        'hostname': socket.gethostname(),
        'server_name': socket.gethostname(),
        'username': username,
        'app_name': 'flask-app',
        'container_id': 1,
        'log_level': 'INFO',
        'message': f"Starting generation of {size_gb}GB of logs by {username}",
        'request_url': '/generate',
        'parameters': f'size={size_gb}',
        'path': '/generate',
        'method': request.method,
        'ip': request.remote_addr,
        'random_number': random.randint(1, 1000)
    }
    
    send_log_to_logstash(log_data)
    logger.info(f"Starting generation of {size_gb}GB of logs by {username}")

    # Start generation in a background thread
    thread = threading.Thread(target=generate_massive_logs, args=(size_gb,))
    thread.daemon = True
    thread.start()

    return f"Started generating {size_gb}GB of logs in the background. Check Kibana for progress."

if __name__ == '__main__':
    # Start Flask app
    logger.info("Flask application starting")
    
    # Start generating logs in background after a short delay
    def delayed_start():
        time.sleep(5)  # Wait for Flask to start
        thread = threading.Thread(target=generate_massive_logs, args=(10,))
        thread.daemon = True
        thread.start()
        
    threading.Thread(target=delayed_start, daemon=True).start()
    
    app.run(host='0.0.0.0', port=5000)