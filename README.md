# Infraestrutura de Banco de Dados — fiap-mecanica-infra-db (Terraform)

Provisiona o RDS MySQL da aplicação `fiap-mecanica`: instância, subnet group e security group.

Um dos **4 repositórios** exigidos pela Fase 3 (Lambda, Infra Kubernetes, Infra de Banco — este
—, Aplicação). Nasceu em 2026-09-03 a partir de uma divisão do repositório `fiap-mecanica`, que
antes concentrava toda a infraestrutura (incluindo o banco) num state só.

## Recursos criados

| Arquivo | Recurso | O que é |
|---|---|---|
| `database.tf` | `aws_db_subnet_group.db_subnet_group` | Subnet group nas subnets públicas do cluster (lidas via remote state) |
| `database.tf` | `aws_security_group.db_sg` | Libera a porta 3306 só para o SG do cluster EKS (lido via remote state) |
| `database.tf` | `aws_db_instance.mysql` | RDS MySQL 8.0 privado (`publicly_accessible = false`), criptografado |

## Dependência do repositório fiap-mecanica-infra-k8s

Este módulo **não cria VPC nem subnets** — lê `vpc_id`, `subnet_id` e
`eks_cluster_security_group_id` do repositório `fiap-mecanica-infra-k8s` via
`data.terraform_remote_state.k8s` (`data.tf`), somente leitura, mesmo bucket S3, chave
`tfstate/terraform.tfstate`. Consequência prática: **o CD daquele repositório precisa ter
rodado com sucesso antes do primeiro CD deste** — numa conta zerada, sem isso o `terraform plan`
falha tentando ler uma chave de state que ainda não existe.

## Migração (2026-09-03) — via `import`, sem derrubar o banco

Diferente de VPC/EKS (que não precisaram de nenhuma operação de state) e diferente de New Relic
(que foi recriado do zero), o RDS foi migrado com `terraform import` — não `destroy`+`create` —
porque:
- o ID de import destes 3 recursos é só o próprio nome/identificador
  (`fiap-mecanica-db-subnet-group`, o ID do SG, `fiap-mecanica-db`), documentado e sem
  ambiguidade — mesmo esforço de um destroy+create;
- destruir e recriar o RDS derrubaria a aplicação por ~10-15 minutos (toda rota que toca o banco
  em 500 nesse meio tempo) — sem motivo, já que importar custa o mesmo.

O RDS é, o tempo todo, o **mesmo recurso físico** — mesmo endpoint, mesmos dados, zero
interrupção real na aplicação durante a migração.

### Uma diferença de `plan` que é esperada e permanente, não um bug

Depois do import, `terraform plan` **nunca** vai mostrar "No changes" para
`aws_db_instance.mysql" — sempre aparecem estas 4 diferenças, todas conhecidas e sem risco:

| Campo | Por quê |
|---|---|
| `password` | A AWS **nunca devolve a senha master** via API — o import fica sem esse valor, e qualquer valor que você passar em `TF_VAR_db_password` aparece como "sendo adicionado". **Nunca rode `terraform apply` sem ter certeza de que esse valor é a senha real** — aplicar com um valor errado rotaciona a senha do banco de produção. |
| `apply_immediately` | Não é um atributo real do RDS, é uma diretriz do Terraform sobre *como* aplicar mudanças futuras — import não reconstrói isso, só um `apply` bem-sucedido grava esse valor no state. |
| `engine_version` (`8.0.46` → `8.0`) | Comportamento documentado do provider AWS: a supressão de diff entre versão-minor-real e versão-configurada depende de um rastreamento interno que só existe em recursos criados via `apply`, não via `import`. Resolve sozinho no primeiro `apply` real. |
| `username` | Metadado de sensibilidade mudando entre versões do provider — o próprio Terraform avisa "o valor não mudou". |

Nenhum desses 4 é destrutivo, e nenhum foi aplicado durante a migração — só o `import` foi
executado. Um `apply` futuro, com a senha real, resolve todos de uma vez.

## Variáveis (`vars.tf`)

| Variável | Default | Descrição |
|---|---|---|
| `project_name` | `fiap-mecanica` | Prefixo do nome dos recursos |
| `region_default` | `us-east-1` | Região AWS |
| `tags` | `{Name = "fiap-mecanica-terraform"}` | Tags aplicadas aos recursos |
| `db_name` | `mecanica` | Nome do banco criado no RDS |
| `db_instance_class` | `db.t3.micro` | Classe da instância RDS |
| `db_username` | — (obrigatório) | Usuário master do RDS |
| `db_password` | — (obrigatório, sensível) | Senha master do RDS |

## Outputs (`output.tf`)

| Output | Uso |
|---|---|
| `db_endpoint` | Consumido pelo `app-infra` do repositório `fiap-mecanica`, via `terraform_remote_state` — monta o `DB_URL` do ConfigMap da aplicação |
| `db_name` | Nome do banco (`mecanica`) |

## CI/CD

- `ci.yml` (Pull Request): `terraform plan`.
- `cd.yml` (push na `main`): `terraform apply`.

Secrets necessários: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN` (sessão da
conta Academy Lab) e `TF_VAR_DB_USERNAME`/`TF_VAR_DB_PASSWORD` — **o mesmo par de credenciais já
usado no repositório `fiap-mecanica`** (que ainda precisa delas para montar o Secret Kubernetes
com que a aplicação conecta no banco).

## Ordem de deploy numa infra do zero

```
1º fiap-mecanica-infra-k8s   (este repositório lê o state dele)
2º fiap-mecanica-infra-db    (este)
3º fiap-mecanica-lambda      (independente)
4º fiap-mecanica             (app-infra lê o state deste)
```

## Destruir

Antes de `fiap-mecanica-infra-k8s` (que este lê), depois do `app-infra`/`apigateway` do
`fiap-mecanica` (que leem este):

```
1º fiap-mecanica (app-infra + apigateway)
2º fiap-mecanica-infra-db (este)
3º fiap-mecanica-infra-k8s
```
