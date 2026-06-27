# Plan — Séparer Codex en 2 homes isolés

> Objectif : `~/.codex` redevient **par défaut, ton compte OpenAI** (app desktop, comme si on n'avait rien touché).
> `~/.codex-openai` devient le home **gratuit** (LiteLLM + DeepSeek/NVIDIA/HF/Ollama), piloté par le launcher.
> Bascule via **`CODEX_HOME` global** (choix validé : on garde l'app desktop pour les deux).

---

## 0. Contraintes & faits établis

- **App Codex = app Microsoft Store** (confirmé : `Codex Installer.exe` repasse par le Store). Impossible d'installer 2 fois.
- **L'app lit `CODEX_HOME`** s'il est posé en variable d'environnement **utilisateur persistante** (`setx`). Une variable passée juste au lancement n'est PAS héritée par une app Store → on utilise une variable User persistante qu'on **bascule** selon le mode.
- **Le CLI `codex` (v0.139) respecte `CODEX_HOME`** de façon fiable (fallback garanti).
- Une seule instance Codex tourne à la fois → la bascule globale est acceptable.
- `LITELLM_KEY` est déjà une variable d'env (= `sk-codex-local`). OK pour le home gratuit.
- Modèles réellement dispo sur le compte (cache) : **`gpt-5.5`, `gpt-5.4`, `gpt-5.4-mini`** (+ `codex-auto-review`). `gpt-5-codex` n'existe plus → c'était LA cause du « ça ne marche pas ».
- Modèle OpenAI par défaut choisi : **`gpt-5.5`**.

## Architecture cible

| Home | Usage | Provider | Lancé par |
|------|-------|----------|-----------|
| `~/.codex` | **Compte OpenAI** (défaut, propre) | `openai` / `gpt-5.5` | App desktop (CODEX_HOME→`~/.codex`) + raccourci « Codex OpenAI » |
| `~/.codex-openai` | **Gratuit** | `litellm` (DeepSeek/NVIDIA/HF) + `ollama` | `codex-launch.ps1` (CODEX_HOME→`~/.codex-openai`) |

---

## 1. Sauvegardes (sécurité)

- [x] `~/.codex/config.toml.bak-before-split-20260627` (déjà fait).
- [ ] `cp ~/.codex/auth.json ~/.codex/auth.json.bak-20260627`
- [ ] Noter la valeur actuelle de `CODEX_HOME` (probablement absente).

## 2. Créer le home gratuit `~/.codex-openai` (NON destructif)

1. `mkdir C:\Users\Nasro\.codex-openai`
2. Copier l'auth (permet aussi un éventuel test) : `cp ~/.codex/auth.json ~/.codex-openai/auth.json`
3. Copier le catalogue Ollama (option 7) : `cp ~/.codex/ollama-launch-models.json ~/.codex-openai/`
4. Écrire `~/.codex-openai/config.toml` **minimal** (pas de plugins/marketplaces → évite tout re-download ; pas de MCP car le gratuit les coupe de toute façon) :

```toml
# ~/.codex-openai/config.toml — HOME DEDIE PROVIDERS GRATUITS (LiteLLM/DeepSeek/NVIDIA/HF/Ollama)
# Gere par C:\Serveurs\Codex Gratuit\codex-launch.ps1. NE PAS confondre avec ~/.codex (compte OpenAI).
model = "deepseek-flash"
model_provider = "litellm"
model_reasoning_effort = "xhigh"
sandbox_mode = "danger-full-access"

[features]
multi_agent = true
memories = true
js_repl = false

[model_providers.litellm]
name = "LiteLLM"
base_url = "http://127.0.0.1:4000/v1/"
wire_api = "responses"
env_key = "LITELLM_KEY"
model_catalog_json = "C:\\Serveurs\\Codex Gratuit\\litellm-codex\\litellm-models.json"

[model_providers.ollama-launch-codex-app]
name = "Ollama"
base_url = "http://127.0.0.1:11434/v1/"
wire_api = "responses"

[profiles.deepseek-flash]
model = "deepseek-flash"
model_provider = "litellm"
[profiles.deepseek]
model = "deepseek"
model_provider = "litellm"
[profiles.nvidia]
model = "nvidia"
model_provider = "litellm"
[profiles.hf]
model = "hf"
model_provider = "litellm"
[profiles.cloud]
model = "minimax-m3:cloud"
model_provider = "ollama-launch-codex-app"
[profiles.local]
model = "cc-ollama"
model_provider = "ollama-launch-codex-app"

[sandbox_workspace_write]
network_access = true

[memories]
```

> Note : pas de `[mcp_servers.node_repl]` ici — le gratuit strippe les MCP (API chat DeepSeek incompatibles). On garde le home gratuit léger.

## 3. Adapter `codex-launch.ps1` (home gratuit + bascule CODEX_HOME)

Modifs à faire dans `C:\Serveurs\Codex Gratuit\codex-launch.ps1` :

1. En tête :
   ```powershell
   $FREE_HOME = "$env:USERPROFILE\.codex-openai"
   $CONFIG    = "$FREE_HOME\config.toml"          # <-- au lieu de ~/.codex
   ```
2. Nouvelle fonction de bascule, appelée AVANT de lancer l'app :
   ```powershell
   function Set-CodexHome([string]$path) {
     [Environment]::SetEnvironmentVariable('CODEX_HOME', $path, 'User')  # persistant -> app Store
     $env:CODEX_HOME = $path                                             # session courante -> proxy/CLI
   }
   ```
3. Dans `Launch-App`, pour les options gratuites (1–5, 7) : `Set-CodexHome $FREE_HOME` juste avant `Start-Process shell:AppsFolder\$AUMID`.
4. **Option 6 (OpenAI) retirée du launcher gratuit** (l'OpenAI passe par son propre raccourci, home `~/.codex`). Sinon : la faire `Set-CodexHome "$env:USERPROFILE\.codex"` puis lancer l'app.
5. Le reste (`Set-Default`, `Set-Reasoning`, `Set-Catalog`, `Strip-MCP`, `Update-LiteLLMConfig`, proxy) opère désormais sur `$CONFIG` = home gratuit → **ne touche plus jamais `~/.codex`**.

## 4. Créer le raccourci « Codex OpenAI » (retour au compte)

Petit script `C:\Serveurs\Codex Gratuit\codex-openai.ps1` :
```powershell
[Environment]::SetEnvironmentVariable('CODEX_HOME', "$env:USERPROFILE\.codex", 'User')
Start-Process "shell:AppsFolder\OpenAI.Codex_2p2nqsd0c76g0!App"
```
+ un raccourci `.lnk` « Codex OpenAI » qui le lance. Garantit `~/.codex` (compte OpenAI) à chaque fois.

## 5. VÉRIFICATION bloquante (avant de nettoyer `~/.codex`)

But : confirmer que **l'app desktop** honore bien `CODEX_HOME` persistant.

1. `Set-CodexHome ~/.codex-openai` (via le launcher gratuit option 1).
2. **Fermer complètement** l'app Codex, la relancer via le launcher.
3. Vérifier : l'app montre les modèles gratuits / écrit dans `~/.codex-openai` (mtime de `~/.codex-openai/*` qui bouge, pas `~/.codex`).
4. Test CLI fiable en parallèle : `$env:CODEX_HOME="$HOME\.codex-openai"; codex` → doit lire ce home.

- ✅ Si l'app lit le home gratuit → passer à l'étape 6.
- ❌ Sinon → NE PAS nettoyer `~/.codex`. Repli : le gratuit tourne via `codex` en terminal (TUI) ; `~/.codex` reste tel quel.

## 6. Nettoyer `~/.codex` → défaut OpenAI (DESTRUCTIF, après vérif OK)

Dans `~/.codex/config.toml` :
- **Header** : `model = "gpt-5.5"`, `model_provider = "openai"`, garder `model_reasoning_effort` (`high` ou `xhigh`), `personality`, `sandbox_mode`, `notify`.
- **SUPPRIMER** : `[model_providers.litellm]`, `[model_providers.ollama-launch-codex-app]`, et les profils gratuits `[profiles.local|cloud|nvidia|deepseek|hf|deepseek-flash]` (sinon référence pendante vers un provider supprimé → erreur).
- **GARDER intact** : `[notice.model_migrations]`, `[windows]`, `[features]`, tous les `[projects.*]`, `[marketplaces.*]`, `[plugins.*]`, `[desktop.*]`, `[hooks.*]`, tous les `[mcp_servers.*]` (node_repl + supabase + render + figma), `[sandbox_workspace_write]`, `[memories]`.
- `[profiles.openai]` : garder mais `model = "gpt-5.5"`.
- **Aucun `model_catalog_json` global** → l'app affiche les vrais modèles OpenAI (gpt-5.5/5.4/5.4-mini).

## 7. Tests finaux

- [ ] Raccourci « Codex OpenAI » → app sur `gpt-5.5`, MCP/plugins actifs, **ne consomme pas via le proxy**.
- [ ] Launcher gratuit (option 1) → proxy :4000 up, DeepSeek répond, `~/.codex` non modifié.
- [ ] Bascule A/R : OpenAI → gratuit → OpenAI, sans corruption.
- [ ] `git` : commit du launcher modifié + ce plan (push manuel par Nasro).

## Rollback (si besoin)

```powershell
cp ~/.codex/config.toml.bak-before-split-20260627 ~/.codex/config.toml
[Environment]::SetEnvironmentVariable('CODEX_HOME', $null, 'User')   # retire la variable
Remove-Item ~/.codex-openai -Recurse -Force
```

## Risques / points d'attention

- **Bascule = dernier mode persiste** : ouvrir l'app depuis le menu Démarrer (sans raccourci) utilise le dernier `CODEX_HOME` posé. Les 2 raccourcis dédiés évitent l'ambiguïté.
- `setx`/SetEnvironmentVariable('User') n'affecte que les **nouveaux** process → **fermer/rouvrir** l'app à chaque bascule.
- `node_repl` (MCP interne) dans `~/.codex` a `CODEX_HOME` codé en dur vers `~/.codex` : sans effet ici (utilisé seulement en mode OpenAI/app, ce qui est cohérent).
- Le home gratuit minimal n'a pas de plugins → si Codex tente d'en réinstaller, surveiller le disque (peu probable sans `[marketplaces]`).
