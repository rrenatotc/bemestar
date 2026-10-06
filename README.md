# Bem Estar Representações: landing e automação de pedidos

Landing estática (`index.html`) que abre o WhatsApp do Daniel e, ao mesmo tempo, manda o pedido para o n8n, que salva o lead e avisa pela Evolution API.

```
Landing ──POST──▶ n8n /webhook/bemestar-pedido ──▶ Postgres (leads_bemestar)
   │                                           └─▶ Evolution: aviso pro Daniel + confirmação pro cliente
   └──▶ wa.me (abre na hora, não espera o POST)
```

## Arquivos

| Arquivo | O que é |
|---|---|
| `index.html` | Landing com o `CONFIG` no topo (`webhookUrl`, `webhookSecret`, `whatsapp`) |
| `sql/leads_bemestar.sql` | Tabela de leads (Supabase ou Postgres) |
| `n8n/bemestar-pedido-landing.json` | Workflow "BemEstar - Pedido Landing" |
| `n8n/bemestar-followup-pendentes.json` | Workflow de follow-up (a cada 1h) |
| `n8n/exemplo-payload.json` | Payload para testar |
| `.env.example` | Variáveis do n8n |

## Setup

1. **Banco:** rode `sql/leads_bemestar.sql` no SQL Editor do Supabase.
2. **Variáveis no n8n (Easypanel → serviço n8n → Environment):** copie o `.env.example` e preencha os valores. `N8N_BLOCK_ENV_ACCESS_IN_NODE=false` é obrigatório, porque os nós leem `$env`. Depois reinicie o serviço.
3. **Importar:** no n8n, use *Import from file* com os dois JSON da pasta `n8n/`. Em cada nó Postgres, selecione a credencial do Supabase (Host, DB, usuário e senha do *Connection pooling* do Supabase).
4. **Landing:** em `CONFIG`, preencha `whatsapp` (55 + DDD + número) e `webhookSecret`, que tem que ser o mesmo valor de `WEBHOOK_SECRET`.
5. **Testar antes de ativar:** abra o workflow, clique em *Execute workflow* (ele fica ouvindo em `/webhook-test/`) e rode:

```bash
curl -X POST "https://zamcat-n8n.c4vo9g.easypanel.host/webhook-test/bemestar-pedido" -H "Content-Type: application/json" -H "x-webhook-secret: SEU_SECRET" --data @n8n/exemplo-payload.json
```

   Confira se a linha apareceu na tabela e se as mensagens chegaram. Para não mandar mensagem a um cliente real, troque o `whatsapp` do exemplo pelo seu número.
6. **Ativar** os dois workflows. A landing usa a URL de produção `/webhook/bemestar-pedido`.

## Como funciona

- **Validação:** confere o header `x-webhook-secret`, descarta quando o honeypot `site` vem preenchido e aplica rate limit de 5 pedidos por IP a cada 10 min. Também normaliza o telefone para `55DDDNÚMERO`, a quantidade para um inteiro entre 1 e 999 e tira os espaços das pontas do nome.
- **Deduplicação:** se chegar o mesmo telefone com os mesmos itens em menos de 10 min, o pedido não é salvo nem avisado. A checagem é feita no próprio `INSERT ... WHERE NOT EXISTS`.
- **Avisos:** o Daniel recebe o resumo, com "🔥 URGENTE" quando o prazo é "Preciso logo". Se o cliente deixou o WhatsApp, recebe a confirmação depois de 8 s de espera e de `delay` com `presence: composing`.
- **Erros:** cada envio para a Evolution é tentado 3 vezes, com 5 s entre as tentativas (é o retry do próprio n8n). Se falhar nas 3, o lead fica com `status = erro_envio`.
- **Follow-up:** de hora em hora, leads em `novo` há mais de 24h entram numa lista que vai para o Daniel. Cada lead é lembrado no máximo 1 vez a cada 24h, pela coluna `lembrado_em`. Quando o Daniel responder, troque o `status` para `respondido`.

## Segurança

- A `apikey` da Evolution fica só nas variáveis do n8n e nunca aparece na landing.
- O `webhookSecret` **fica visível no código da landing**, porque o site é público. Ele só filtra robôs genéricos. A proteção de verdade vem do honeypot, do rate limit e da deduplicação.
- O rate limit usa o *static data* do workflow, que só é gravado em execuções de produção (workflow ativo).
