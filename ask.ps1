# ============================================================
#  ASK AI - Simple Terminal LLM Assistant
#  Run directly: irm https://tinyurl.com/ask-examai | iex
#  Zero setup required - works instantly on any computer!
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

    Write-Host "$dim  Type your question. Type 'exit' to quit.$reset"
    Write-Host "$dim  ─────────────────────────────────────────────$reset"
    Write-Host ""

    $proxyUrl = "https://portal-olive-ten.vercel.app/api/chat"

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

        # Build payload matching Gemini structure
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
            # Call our Vercel API proxy
            $response = Invoke-RestMethod -Uri $proxyUrl -Method POST -Body $body -ContentType "application/json; charset=utf-8" -ErrorAction Stop

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
            if ($errMsg -match "503") {
                Write-Host "$red  Gemini API is currently overloaded. Please wait a moment and try again.$reset"
            } else {
                Write-Host "$red  Error contacting admin portal proxy: $errMsg$reset"
            }
            Write-Host ""
        }
    }
}

# Auto-run
Start-AskAI
