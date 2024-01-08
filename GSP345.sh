#!/bin/sh

cat << EOF >> ~/.vimrc
autocmd BufEnter,BufNew *.tf,*.tfvars setlocal ai ts=2 sw=2 et
" run 'terraform fmt' after terraform file is saved
autocmd BufWritePost *.tf,*.tfvars !terraform fmt %
EOF

export REGION=us-west1
export ZONE=us-west1-c
export PROJECT_ID=`gcloud config list --format 'value(core.project)'`
export BUCKET_NAME=tf-bucket-626122
export INSTANCE_NAME=tf-instance-157152
export NETWORK_NAME=tf-vpc-312777


########## TASK 1
mkdir -p modules/{instances,storage}
cat << EOF > variables.tf
variable "region" {
  description = "GCP region."
  default = "${REGION}"
}

variable "zone" {
  description = "GCP zone."
  default = "${ZONE}"
}

variable "project_id" {
  description = "GCP project_id."
  default = "${PROJEC_ID}"
}
EOF
ln variables.tf modules/instances/ && ln variables.tf modules/storage/

cat << EOF > main.tf
terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
      version = "4.0.0"
    }
  }
}

provider "google" {
  project     = var.project_id
  region      = var.region
  zone        = var.zone
}

module "instances" {
  source = "./modules/instances"
}
EOF


########## TASK 2
cat << EOF > modules/instances/instances.tf
resource "google_compute_instance" "tf-instance-1" {
  project      = var.project_id
  zone         = var.zone
  name         = "tf-instance-1"
  machine_type = "e2-micro"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    network = "default"
    access_config {
    }
  }
  metadata = {
    "startup-script" = <<-EOT
                #!/bin/bash
            EOT
  }
  allow_stopping_for_update = true
}

resource "google_compute_instance" "tf-instance-2" {
  project      = var.project_id
  zone         = var.zone
  name         = "tf-instance-2"
  machine_type = "e2-micro"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    network = "default"
    access_config {
    }
  }
  metadata = {
    "startup-script" = <<-EOT
                #!/bin/bash
            EOT
  }
  allow_stopping_for_update = true
}
EOF

terraform import module.instances.google_compute_instance.tf-instance-1 ${PROJECT_ID}/${ZONE}/tf-instance-1
terraform import module.instances.google_compute_instance.tf-instance-2 ${PROJECT_ID}/${ZONE}/tf-instance-2


########## TASK 3
cat << EOF > modules/storage/storage.tf
resource "google_storage_bucket" "backend" {
  name        = "${BUCKET_NAME}"
  location    = "US"
  force_destroy = true
  uniform_bucket_level_access = true
}
EOF

cat << EOF >> main.tf

module "storage" {
  source = "./modules/storage"
}
EOF
terraform init
terraform apply

vi main.tf
  backend "gcs" {
    bucket = "${BUCKET_NAME}"
    prefix = "terraform/state"
  }
terraform init


########## TASK 4
sed -i 's/machine_type = .\+/machine_type = "e2-standard-2"/' modules/instances/instances.tf
cat << EOF >> modules/instances/instances.tf

resource "google_compute_instance" "tf-instance-183916" {
  project      = var.project
  zone         = var.zone
  name         = "${INSTANCE_NAME}"
  machine_type = "e2-standard-2"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    network = "default"
    access_config {
    }
  }
  metadata = {
    "startup-script" = <<-EOT
                #!/bin/bash
            EOT
  }
  allow_stopping_for_update = true
}
EOF
terraform apply


########## TASK 5
sed -i "/${INSTANCE_NAME}/,/^}/d" modules/instances/instances.tf
terraform apply


########## TASK 6
cat << EOF >> main.tf

module "network" {
  source  = "terraform-google-modules/network/google"
  version = "6.0.0"
  project_id     = var.project_id
  network_name   = "${NETWORK_NAME}"
  routing_mode   = "GLOBAL"

  subnets = [
  {
      subnet_name = "subnet-01"
      subnet_ip = "10.10.10.0/24"
      subnet_region = "${REGION}"
  },
  {
      subnet_name = "subnet-02"
      subnet_ip = "10.10.20.0/24"
      subnet_region = "${REGION}"
  },
  ]
}
EOF
terraform init
terraform apply

sed -i '/tf-instance-1/,/^}/s/network = .*/subnetwork = "subnet-01"/' modules/instances/instances.tf
sed -i '/tf-instance-2/,/^}/s/network = .*/subnetwork = "subnet-02"/' modules/instances/instances.tf
terraform apply


########## TASK 7
vi main.tf
firewall_rules = [
{
  name = "tf-firewall"
  direction = "INGRESS"
  ranges = ["0.0.0.0/0"]
  allow = [{
    protocol = "tcp"
    ports = ["80"]
  }]
},
]
