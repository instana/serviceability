# IBM MQ Must Gather Script

## Overview

The `mq_status.sh` script will collect the configuration data from running IBM MQ

## Usage

1. Copy the script to the environment where ibm mq is running
2. Make the scirpt executable.
   
   ```bash
   chmod +x mq_status.sh
   ```
3. Run the script

   ```bash
   ./mq_status.sh QueueManagerName
   ```

   This will display the below details:
   - Queue manager definition and status
   - Channel definition and status - Look for only CHLTYPE(SVRCONN) which is what we need in agent configuration
   - Listener definition and status – Check the port and status
   
