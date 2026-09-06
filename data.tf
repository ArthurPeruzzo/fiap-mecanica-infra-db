# Leitura somente-leitura do state do repositório fiap-mecanica-infra-k8s — nunca escreve lá.
# vpc_id/subnet_id/eks_cluster_security_group_id são recursos que este repositório não possui;
# ler por remote state evita duplicar VPC/rede aqui, e mantém o RDS na mesma rede do cluster.
data "terraform_remote_state" "k8s" {
  backend = "s3"
  config = {
    bucket = "fiap-mecanica"
    key    = "tfstate/terraform.tfstate"
    region = "us-east-1"
  }
}
