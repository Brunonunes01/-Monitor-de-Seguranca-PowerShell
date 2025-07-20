# -Monitor-de-Seguranca-PowerShell
# 🛡 Monitor de Segurança PowerShell

Projeto desenvolvido por *Bruno Henrique Borascho Nunes* como *trabalho acadêmico* para fins educacionais, com apoio de Inteligência Artificial (IA). O script tem como objetivo monitorar a execução de processos no sistema, realizando automaticamente *captura de imagem pela webcam* e *gravação da tela* ao detectar atividades pré-definidas.

> 🎓 Este projeto foi finalizado como parte das atividades do curso de Análise e Desenvolvimento de Sistemas da Fatec Jales.

## 🧠 Objetivo

Criar uma ferramenta de monitoramento que registre visualmente a execução de aplicativos específicos em tempo real. O foco está em aplicações voltadas à segurança e controle de uso de estações de trabalho.

## 🚀 Funcionalidades

- 📸 Captura automática de imagem pela webcam ao detectar processo monitorado.
- 🎥 Gravação da tela com FFmpeg em tempo real.
- 📊 Log detalhado com timestamp e classificação (INFO, ALERT, ERROR).
- 🧠 Gerenciamento inteligente de múltiplas gravações simultâneas.
- 🖥 Detecção automática da resolução da tela.

## ⚙ Tecnologias e Ferramentas

- *PowerShell (Windows Script)*
- *FFmpeg* para captura de vídeo e imagem
- Manipulação de diretórios e processos no Windows
- Controle de jobs assíncronos com Start-Job e Register-ObjectEvent

## 🔍 Processos Monitorados

Por padrão, o script observa os seguintes processos (editável):

- powershell
- cmd
- regedit
- taskmgr
- Navegadores: msedge, firefox
- Mensageiros: WhatsApp, Telegram, Discord

## 🗂 Estrutura de Pastas

O script cria automaticamente os seguintes diretórios, se não existirem:

- C:\Fotos — capturas da webcam
- C:\Videos — gravações da tela
- C:\Logs — arquivos .log com registros de eventos

## 📝 Observações

- As gravações são feitas com duração padrão de *60 segundos* (ajustável).
- A resolução da tela é detectada automaticamente.
- Fotos e vídeos são nomeados com base no processo e timestamp.
- Arquivos corrompidos ou com falhas são descartados.
- Log de erros é mantido para auditoria.

## 📌 Exemplo de Aplicação

- Ambientes escolares/laboratoriais
- Monitoramento em estações de acesso público
- Projetos educacionais de segurança

## 👨‍🏫 Informações Acadêmicas

- *Curso:* Análise e Desenvolvimento de Sistemas  
- *Instituição:* Faculdade de Tecnologia Professor José Camargo – Fatec Jales  
- *Aluno:* Bruno Henrique Borascho Nunes  
- *Ano:* 2025  
- *Observação:* Projeto desenvolvido com auxílio de IA, com finalidade didática.

## 📄 Licença

Uso exclusivamente educacional.  
Todos os direitos reservados ao autor.

---