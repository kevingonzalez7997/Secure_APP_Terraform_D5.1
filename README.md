[# Terraform Infrastructure with Jenkins Agent (5.1)
### October 20, 2023
### Kevin Gonzalez

## Purpose

This deployment leverages Terraform, an Infrastructure as Code (IaC) tool, to provision the necessary infrastructure for hosting a banking application server. To streamline the process, Jenkins is integrated for automated building and testing, and Gunicorn is the application hosting server. Furthermore, we've enhanced security by utilizing Jenkins agents

## Deployment Steps

### 1. Provisioning Infrastructure Using Terraform

Terraform, an open-source IaC tool, simplifies infrastructure management with its declarative configuration language. It supports multiple cloud providers and enables efficient provisioning.

In this deployment, Terraform creates the following [resources]():

- 1 Virtual Private Cloud (VPC)
- 2 Availability Zones (AZs)
- 2 Public Subnets
- 3 EC2 instances (Jenkins and 2 Agents)
- 1 Route Table
- Security Group with open ports: 8080, 8000, and 22

Additionally, Terraform's capabilities are used to install [Jenkins](https://github.com/kevingonzalez7997/Jenkins_install) during the EC2 creation process. The following command is included in the first EC2 resource block:
- `user_data = "${file("jenkins_install_script.sh")}"`

### 2. Generate a New Key Pair in AWS

To launch two Jenkins agents for hosting the application, we'll use SSH.

- Navigate to EC2 in the AWS console.
- Under Network & Security, find Key Pairs.
- Create a new pair and save the private key.

### 3. Git / GitHub

Git is a widely used distributed version control system (DVCS) for tracking changes in source code during software development. GitHub, a web-based platform, provides hosting for Git repositories and is one of the most popular platforms for version control and collaborative software development.

In this deployment, [git](https://github.com/kevingonzalez7997/Git_Cloning) is used to create a second branch, allowing changes to be deployed in a staging environment. Once the changes are ready, they can be pushed to the Source Code Management (SCM), in this case, GitHub.

### 4. Install Dependencies

All three instances require the following dependencies. They are needed on the Jenkins server for testing and building before allowing the two agents to deploy. The two agents need these dependencies installed before deploying the application.

- Install `software-properties-common`: `sudo apt install -y software-properties-common`
- Add the `deadsnakes` repository for Python 3.7: `sudo add-apt-repository -y ppa:deadsnakes/ppa`
- Install Python 3.7: `sudo apt install -y python3.7`
- Install Python 3.7 virtual environment: `sudo apt install -y python3.7-venv`

### 5. Jenkins Agents

Jenkins, an open-source automation server, is used for building, testing, and deploying code, and it can distribute workloads. Since two instances are been used, create two agents in the master. Jenkins Master is the central server that manages jobs, schedules builds and distributes tasks to agents.

- Create a new node.
- Specify name and location.
- Select "Launch agent via SSH" (using the previously saved key).
- The host will be the public IP of the agent instance (App_ec2_1/2).
- Create credentials by entering the private key directly.
- Save and check the log to verify agent status.
- Create a second node with the same configuration; the only change should be the public IP.

## 6. Jenkins Pipeline

GitHub Is one of the most popular open-source repository platforms. The code will be pulled from a GitHub repository that has been created, which is a more practical approach.

- Create a new Jenkins item and select "Multi-branch pipeline."
- Configure Jenkins Credentials Provider as needed.
- Copy and import the Repository URL where the application source code resides.
- Use your GitHub username and the generated key from GitHub as your credentials.

### 7. Installing CloudWatch

Minimizing downtime is crucial for a successful application. To optimize the application from the previous build, we've implemented a monitoring system. Since we're using AWS, we've utilized CloudWatch for native integration. It's also cost-efficient because you only pay for the services you need.

To install, run the following:

- `wget https://amazoncloudwatch-agent.s3.amazonaws.com/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb` to download the install package file.
- `sudo dpkg -i -E ./amazon-cloudwatch-agent.deb` to run the install package.
- `cd /opt/aws/amazon-cloudwatch-agent/bin/` to navigate to the app location.
- `sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-config-wizard` to launch the setup wizard and configure in greater detail.
- `/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c file:/opt/aws/amazon-cloudwatch-agent/bin/config.json` to launch the agent. You can check the status with:
- `sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -m ec2 -a status`

## Troubleshooting

### Observations

changes to the Jenkins file are required to ensure parallelism. When declaring which agent Jenkins should be used, be sure to include both agent names

- `agent {label 'awsDeploy || awsDeploy2'}`

You can make these changes to the Jenkins file in the second branch. When the application is deployed, you can verify performance and send a merge request.

## Optimization

While this version of the deployment was an improvement over the previous one, there are ways to further increase resilience and streamline the pipeline. Since two instances are hosting the application, they could be deployed in their own Availability Zones (AZs) to reduce single points of failure.

Docker could significantly increase automation in the pipeline. In this version, each instance that handled the application had to have requirements manually installed beforehand, which is time-consuming and counterproductive. Docker can create an image with all the required dependencies to be run in a container.

## Conclusion

Improvements have been made to the current deployment version. This infrastructure includes a second instance to host the application, increasing resilience. If one instance crashes, users will still be able to access the application. In addition, we've used Jenkins' built-in function of nodes to increase security. ](https://github.com/kevingonzalez7997/Secure_APP_Terraform_D5.1.git)https://github.com/kevingonzalez7997/Secure_APP_Terraform_D5.1.git
