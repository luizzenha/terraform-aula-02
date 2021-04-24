# Setup

Necessário AWS Cli instalado e configurado

Para iniciar e instalar os modulos AWS

``` terraform init ```

Para efetuar a criação do ambiente, por default está utilizando *us-east-2*

``` terraform apply ```

Ao finalizar ele exibira o IP que foi associado a VM

# Conexão Mysql
```
 - host: <IP>
 - port: 3306
 - user: zenha
 - password: zenha

```

# Conexão SSH

No arquivo *terraform.tfstate* que foi gerado, você encontrará a private key (private_key_pem), use-a para conectar

```
ssh -i <keyfile> ubuntu@<IP>
```

Obs: O arquivo da chave é gerado com \n é preciso removê-los
