#!/bin/bash

        # Finalidade    : Criar kubeconfig
        # Input         : Credenciais Kubectl
        # Output        : kubeconfig
        # Autor         : Marcos de Benedicto (shellmaker.io)
        # Data          : 18/11/2017

set -e

function RC() #Funções de retorno de erro e messages
{
        RC=$1
        echo "$2"
        [ $RC == 0 ] && exit 0
        [ $RC == 1 ] && exit 1

}

[ $# == 0 ] && RC 1 "Usage: $0 SERVICEACCOUNT [kubectl options]"

function _kubectl()
{
          kubectl $@ $kubectl_options #Preguiça de digitar tudo. :-)
}

serviceaccount="$1"
kubectl_options="${@:2}" #Captura segunda variavel de entrada

[ ! secret="$(_kubectl get serviceaccount "$serviceaccount" -o 'jsonpath={.secrets[0].name}')" ] && RC 1 "serviceaccounts \"$serviceaccount\" not found."

[ -z "$secret" ] && RC 1 "serviceaccounts \"$serviceaccount\" doesn't have a serviceaccount token."

# context
context="$(_kubectl config current-context)"

# cluster
cluster="$(_kubectl config view -o "jsonpath={.contexts[?(@.name==\"$context\")].context.cluster}")"
server="$(_kubectl config view -o "jsonpath={.clusters[?(@.name==\"$cluster\")].cluster.server}")"

# token
ca_crt_data="$(_kubectl get secret "$secret" -o "jsonpath={.data.ca\.crt}" | openssl enc -d -base64 -A)"
namespace="$(_kubectl get secret "$secret" -o "jsonpath={.data.namespace}" | openssl enc -d -base64 -A)"
token="$(_kubectl get secret "$secret" -o "jsonpath={.data.token}" | openssl enc -d -base64 -A)"

export KUBECONFIG="$(mktemp)"
kubectl config set-credentials "$serviceaccount" --token="$token" >/dev/null

ca_crt="$(mktemp)"; echo "$ca_crt_data" > $ca_crt

kubectl config set-cluster "$cluster" --server="$server" --certificate-authority="$ca_crt" --embed-certs >/dev/null
kubectl config set-context "$context" --cluster="$cluster" --namespace="$namespace" --user="$serviceaccount" >/dev/null
kubectl config use-context "$context" >/dev/null

cat "$KUBECONFIG"
