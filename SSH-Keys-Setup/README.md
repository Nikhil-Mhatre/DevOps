# SSH Key Setup for GitHub (Git Bash on Windows)

This guide walks you through generating and configuring an SSH key for GitHub using Git Bash on Windows. SSH keys provide a secure, password-free way to authenticate with remote repositories.

---

## Prerequisites

- Git for Windows (includes Git Bash) — [Download here](https://git-scm.com/download/win)
- A GitHub account

---

## Step 1 — Open Git Bash

Launch **Git Bash** from the Start Menu or right-click any folder and select **"Git Bash Here"**.

---

## Step 2 — Generate a New SSH Key

```bash
ssh-keygen -t ed25519 -C "your-email@example.com" -f ~/.ssh/github-<YOUR_NAME>
```

| Flag | Description |
| --- | --- |
| `-t ed25519` | Uses the Ed25519 algorithm (modern, secure, and recommended) |
| `-C "your-email"` | Attaches a label/comment to identify the key |
| `-f ~/.ssh/github-<YOUR_NAME>` | Saves the key pair with a custom filename |

> **Tip:** Replace `your-email@example.com` with the email associated with your GitHub account.
> 

---

## Step 3 — Set a Passphrase (Optional but Recommended)

When prompted, you can either set a passphrase for added security or press **Enter** to skip:

```
Enter passphrase (empty for no passphrase):
Enter same passphrase again:
```

> A passphrase encrypts the private key locally, adding an extra layer of protection if your machine is compromised.
> 

---

## Step 4 — Verify the Generated Key Files

```bash
ls -la ~/.ssh/
```

You should see two new files:

| File | Description |
| --- | --- |
| `github-<YOUR_NAME>` | **Private key** — keep this secret, never share it |
| `github-<YOUR_NAME>.pub` | **Public key** — this is what you upload to github |

---

## Step 5 — Start the SSH Agent

The SSH agent manages your keys in memory, so you don't need to re-enter your passphrase repeatedly.

```bash
eval "$(ssh-agent -s)"
```

Expected output:

```
Agent pid 1234
```

---

## Step 6 — Add Your Key to the SSH Agent

```bash
ssh-add ~/.ssh/github-<YOUR_NAME>
```

> If you set a passphrase in Step 3, you'll be prompted to enter it here.
> 

---

## Step 7 — Copy the Public Key

```bash
cat ~/.ssh/github-<YOUR_NAME>.pub | clip
```

This copies the public key to your clipboard.

> **Alternatively**, open the file manually and copy its contents — it will look like:
`ssh-ed25519 AAAA... your-email@example.com`
> 

---

## Step 8 — Add the Public Key to github

1. Sign in to your GitHub account
2. Click on **User Navigation Menu (Avatar)** on Top Right Side → Settings.
3. Navigate to **Access → SSH and GPG Keys**.
4. Click on **New SSH Key** to add new key.
5. Paste the copied public key into the **Key** field
6. Add a descriptive **Title** (e.g., `Work Laptop - Windows`)
7. Select a **Key Type** to **Authentication Key**
8. Click **Add key**

<img width="1904" height="878" alt="image" src="https://github.com/user-attachments/assets/0b8b39b4-49bc-46bd-91d0-6472c4430ee4" />

---

## Step 9 — Test the SSH Connection

```bash
ssh -T git@github.com
```

On first connection, you may see a host verification prompt — type `yes` to continue.

Expected output:

```
Welcome to github, @your-username!
```

If you see this message, your SSH key is set up correctly. ✓

---

## Step 10 — (Optional) Configure SSH for Multiple Keys

If you work with multiple Git hosts or accounts, create or edit the SSH config file to specify which key to use per host:

```bash
nano ~/.ssh/config
```

Add the following block:

```
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/github-<YOUR_NAME>
    IdentitiesOnly yes
```

Save and exit (`Ctrl+O`, then `Ctrl+X`).

> **`IdentitiesOnly yes`** ensures SSH uses only the specified key and ignores other loaded keys — important when you have multiple accounts.
> 

---

## Step 11 — Verify Your Git Remote Uses SSH

Check the remote URL of your repository:

```bash
git remote -v
```

An SSH remote looks like:

```
origin  git@github.com:username/repository.git (fetch)
origin  git@github.com:username/repository.git (push)
```

If the URL starts with `https://`, switch it to SSH:

```bash
git remote set-url origin git@github.com:username/repository.git
```

---

## Troubleshooting

### `Permission denied (publickey)`

Your key is not loaded in the agent. Run:

```bash
ssh-add ~/.ssh/github-<YOUR_NAME>
```

Then retry the connection test.

---

### SSH Agent is not running

Start the agent manually:

```bash
eval "$(ssh-agent -s)"
```

---

### Check which keys are loaded in the agent

```bash
ssh-add -l
```

If the output is `The agent has no identities`, re-add your key (see above).

---

### Debug connection issues

For verbose output that helps diagnose SSH problems:

```bash
ssh -vT git@github.com
```

---

## Key File Reference

| File | Path |
| --- | --- |
| Private key | `~/.ssh/github-<YOUR_NAME>` |
| Public key | `~/.ssh/github-<YOUR_NAME>.pub` |
| SSH config | `~/.ssh/config` |

> **Security reminder:** Your private key (`github-<YOUR_NAME>`) should **never** be shared, uploaded, or committed to any repository.
>
