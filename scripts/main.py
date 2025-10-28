import os
import json
import logging
from datetime import datetime

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

def load_config(config_file_path):
    """
    Loads configuration from a JSON file.
    """
    if not config_file_path:
        logging.error("Configuration file path is empty or not provided.")
        return None
    try:
        with open(config_file_path, 'r') as f:
            config = json.load(f)
        return config
    except FileNotFoundError:
        logging.error(f"Configuration file not found at: {config_file_path}")
        return None
    except json.JSONDecodeError:
        logging.error(f"Error decoding JSON from file: {config_file_path}. Check file format.")
        return None
    except Exception as e:
        logging.error(f"An unexpected error occurred while loading config: {e}")
        return None

def validate_config(config):
    """
    Validates essential configuration parameters.
    """
    if not config:
        return False, "Configuration is empty or could not be loaded."
    
    # These are the expected keys from app_config.json
    required_keys = ["environment", "service_name", "deploy_target", "base_artifacts_dir", "artifact_name_pattern"]
    for key in required_keys:
        if key not in config:
            return False, f"Missing required configuration key: '{key}'"
    
    if not isinstance(config.get("deploy_target"), str) or not config["deploy_target"]:
        return False, "'deploy_target' must be a non-empty list."
    
    return True, "Configuration validated successfully."

def resolve_artifacts_path(base_dir, pattern, service_name):
    """
    Resolves the actual artifacts path based on a pattern and current date.
    """
    # Using the current date for dynamic path
    current_date = datetime.now().strftime("%Y%m%d")
    resolved_segment = pattern.format(service_name=service_name, date=current_date)
    full_path = os.path.join(base_dir, resolved_segment)
    return full_path

def simulate_deployment(service_name, target_server, artifacts_path):
    """
    Simulates a deployment to a target server.
    """
    logging.info(f"Initiating deployment for service '{service_name}' to '{target_server}' from '{artifacts_path}'...")
    import time
    time.sleep(1)

    # This is the check that will fail if the dynamic directory isn't created
    if not os.path.exists(artifacts_path) or not os.path.isdir(artifacts_path):
        logging.error(f"Artifacts path '{artifacts_path}' does not exist or is not a directory. Deployment aborted!")
        return False
    
    # Simulate finding some artifact files inside the expected directory
    artifact_files = [f for f in os.listdir(artifacts_path) if os.path.isfile(os.path.join(artifacts_path, f))]
    if not artifact_files:
        logging.warning(f"No artifact files found in '{artifacts_path}'. This might indicate an incomplete build.")
    else:
        logging.info(f"Found artifacts: {', '.join(artifact_files)}")

    logging.info(f"Deployment of '{service_name}' to '{target_server}' completed successfully.")
    return True

if __name__ == "__main__":
    # --- Configuration setup ---
    SCRIPT_DIR = os.path.dirname(__file__)
    # Default path if environment variable is not used or invalid
    DEFAULT_CONFIG_FILE_PATH = os.path.join(SCRIPT_DIR, "config", "app_config.json")
    
    # Attempt to get config path from environment variable
    APP_CONFIG_PATH_ENV = os.getenv("APP_CONFIG_PATH") 
    
    config_path_to_use = None

    if APP_CONFIG_PATH_ENV:
        logging.info(f"Environment variable APP_CONFIG_PATH is set: '{APP_CONFIG_PATH_ENV}'")
        if os.path.exists(APP_CONFIG_PATH_ENV) and os.path.isfile(APP_CONFIG_PATH_ENV):
            config_path_to_use = APP_CONFIG_PATH_ENV
            logging.info(f"Using config path from environment variable: {config_path_to_use}")
        else:
            logging.error(f"Environment variable APP_CONFIG_PATH '{APP_CONFIG_PATH_ENV}' does not point to a valid file. This is required for deployment.")
            print("Deployment aborted: Invalid environment configuration path.")
            exit(1)
    else:
        logging.error("APP_CONFIG_PATH environment variable is not set. This is required for deployment.")
        print("Deployment aborted: Missing environment configuration path.")
        exit(1)

    # --- Load and validate config ---
    app_config = load_config(config_path_to_use)

    # Ensure config was loaded before trying to validate
    if app_config is None:
        print("Deployment aborted: Failed to load configuration.")
        exit(1)

    is_valid, validation_message = validate_config(app_config)

    if not is_valid:
        logging.error(f"Configuration validation failed: {validation_message}")
        print("Deployment aborted due to configuration issues.")
        exit(1)

    # --- Resolve dynamic artifacts path ---
    resolved_artifacts_path = resolve_artifacts_path(
        app_config["base_artifacts_dir"],
        app_config["artifact_name_pattern"],
        app_config["service_name"]
    )
    logging.info(f"Resolved deployment artifacts path: {resolved_artifacts_path}")

    # --- Perform deployments ---
    logging.info(f"Starting deployments for environment: {app_config['environment']}")
    for target in app_config["deploy_target"]:
        success = simulate_deployment(
            app_config["service_name"],
            target,
            resolved_artifacts_path
        )
        if not success:
            logging.error(f"Deployment to {target} failed. Halting further deployments.")
            print("Deployment process failed.")
            exit(1)
    
    logging.info("All deployments completed successfully!")
    print("Deployment process finished.")