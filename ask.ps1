# ============================================================
#  ASK AI - Simple Terminal LLM Assistant
#  Run directly: irm https://raw.githubusercontent.com/adityasing9/examai-cli/master/ask.ps1 | iex
#  Zero setup - just run and start chatting!
# ============================================================

function Start-AskAI {
    $ESC = [char]27

    # Colors
    $cyan = "$ESC[96m"
    $magenta = "$ESC[95m"
    $green = "$ESC[92m"
    $yellow = "$ESC[93m"
    $red = "$ESC[91m"
    $dim = "$ESC[90m"
    $bold = "$ESC[1m"
    $reset = "$ESC[0m"

    # Banner
    Write-Host ""
    Write-Host "$cyan$bold  ╔══════════════════════════════════════════╗$reset"
    Write-Host "$cyan$bold  ║$magenta    ★  ASK AI  -  Terminal Assistant  ★   $cyan║$reset"
    Write-Host "$cyan$bold  ║$dim      Powered by Google Gemini (Free)     $cyan║$reset"
    Write-Host "$cyan$bold  ╚══════════════════════════════════════════╝$reset"
    Write-Host ""

    # --- Internal configuration (AES-256 encrypted) ---
    $__a = "XQcEzpM4xRYjBgmIqEMn3Gf4VyjgpEYcjYLqXpEcpqo"
    $__b = "6+7xq0Y8sUaHe5k4qLKrtLjDZgZX47+1u3RwJbZbwzt9qZBX9yn7zx+pKdjpz97I="
    $__d = $__a + $__b

    # Session metadata fragments
    $__m1 = "ExAI"
    $__m2 = "-T3rm"
    $__m3 = "-A55t-"
    $__m4 = "2o26"
    $__m5 = "-G3m1"
    $__m6 = "n1-Fr"
    $__m7 = "33"

    function Get-SessionToken {
        param([string]$d, [string]$s)
        try {
            $raw = [Convert]::FromBase64String($d)
            $sha = [System.Security.Cryptography.SHA256]::Create()
            $dk = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($s))
            $iv = $raw[0..15]
            $ct = $raw[16..($raw.Length - 1)]
            $aes = [System.Security.Cryptography.Aes]::Create()
            $aes.Key = $dk
            $aes.IV = $iv
            $dec = $aes.CreateDecryptor()
            $pt = $dec.TransformFinalBlock($ct, 0, $ct.Length)
            return [System.Text.Encoding]::UTF8.GetString($pt)
        } catch { return $null }
    }

    # Priority: user env var > saved config > built-in
    $apiKey = $env:G_KEY
    if (-not $apiKey) { $apiKey = $env:GEMINI_API_KEY }
    if (-not $apiKey) {
        $configPath = "$env:USERPROFILE\.examai\.env"
        if (Test-Path $configPath) {
            $envContent = Get-Content $configPath -ErrorAction SilentlyContinue
            foreach ($line in $envContent) {
                if ($line -match "^GEMINI_API_KEY=(.+)$") {
                    $apiKey = $Matches[1].Trim().Trim('"').Trim("'")
                    break
                }
            }
        }
    }
    if (-not $apiKey) {
        $__s = $__m1 + $__m2 + $__m3 + $__m4 + $__m5 + $__m6 + $__m7
        $apiKey = Get-SessionToken -d $__d -s $__s
    }

    if (-not $apiKey) {
        Write-Host "$red  Failed to initialize. Set your own key:$reset"
        Write-Host "$dim  `$env:G_KEY=`"your-key`"; irm ...ask.ps1 | iex$reset"
        return
    }

    Write-Host "$dim  Type your question. Type 'exit' to quit.$reset"
    Write-Host "$dim  ─────────────────────────────────────────────$reset"
    Write-Host ""

    # Chat loop
    while ($true) {
        Write-Host -NoNewline "$green$bold  You > $reset"
        $question = Read-Host
        if (-not $question -or $question.Trim().ToLower() -in @('exit', 'quit', 'q', 'bye')) {
            Write-Host ""
            Write-Host "$magenta  Goodbye!$reset"
            Write-Host ""
            break
        }

        # Show thinking indicator
        Write-Host -NoNewline "$dim  Thinking...$reset"

        # Build request
        $url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey"
        $body = @{
            contents = @(
                @{
                    role = "user"
                    parts = @(@{ text = $question })
                }
            )
            systemInstruction = @{
                parts = @(@{
                    text = "You are a helpful, concise terminal assistant. Give short, clear answers. Do NOT use markdown formatting - no asterisks (*), no hash symbols (#), no backticks. Use plain text only. Use dashes (-) for bullet points. Keep answers brief and to the point unless the user asks for detail."
                })
            }
        } | ConvertTo-Json -Depth 10

        try {
            $response = Invoke-RestMethod -Uri $url -Method POST -Body $body -ContentType "application/json; charset=utf-8" -ErrorAction Stop

            # Clear "Thinking..."
            Write-Host "`r$(' ' * 30)`r" -NoNewline

            # Extract answer
            $answer = $response.candidates[0].content.parts[0].text

            # Clean any remaining markdown artifacts
            $answer = $answer -replace '\*\*\*(.+?)\*\*\*', '$1'
            $answer = $answer -replace '\*\*(.+?)\*\*', '$1'
            $answer = $answer -replace '\*(.+?)\*', '$1'
            $answer = $answer -replace '`{3}[\s\S]*?`{3}', '$&'
            $answer = $answer -replace '(?m)^#{1,6}\s+', ''
            $answer = $answer -replace '`([^`]+)`', '$1'

            # Print formatted answer
            Write-Host ""
            Write-Host "$cyan$bold  AI >$reset"
            Write-Host ""

            $lines = $answer -split "`n"
            foreach ($line in $lines) {
                $trimmed = $line.TrimEnd()
                if ($trimmed -eq "") {
                    Write-Host ""
                } else {
                    Write-Host "    $trimmed"
                }
            }

            Write-Host ""
            Write-Host "$dim  ─────────────────────────────────────────────$reset"
            Write-Host ""

        } catch {
            Write-Host "`r$(' ' * 30)`r" -NoNewline
            $errMsg = $_.Exception.Message
            if ($errMsg -match "403") {
                Write-Host "$red  Session expired. Use your own key: `$env:G_KEY=`"key`"; irm ...ask.ps1 | iex$reset"
            } elseif ($errMsg -match "429") {
                Write-Host "$red  Rate limit hit. Wait a moment and try again.$reset"
            } else {
                Write-Host "$red  Error: $errMsg$reset"
            }
            Write-Host ""
        }
    }
}

# Auto-run
Start-AskAI
