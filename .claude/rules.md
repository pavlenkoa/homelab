# Development Rules

<rules>
    <!-- Universal Programming Rules -->
    <rule importance="critical">Write succinct production-ready code.</rule>
    <rule importance="critical">Never produce incomplete code, always finish the implementation.</rule>
    <rule importance="critical">Figure out the root cause of the issue and fix it.</rule>
    <rule importance="critical">Break large tasks into smaller subtasks.</rule>
    <rule importance="critical">If something is unclear or too complex, ask for clarification.</rule>
    <rule importance="critical">Read the codebase to understand the context.</rule>
    <rule importance="critical">Only commit when explicitly asked to.</rule>
    <rule importance="critical">Be brutally honest and thorough.</rule>
    <rule importance="critical">Do not make assumptions.</rule>
    <rule importance="high">When logging to console, stringify JSON for easy copy and paste.</rule>
    
    <!-- Homelab-Specific Rules -->
    <rule importance="critical">Always use make commands instead of direct docker/python.</rule>
    <rule importance="critical">Edit existing files rather than creating new ones.</rule>
    <rule importance="critical">Never commit .env files or secrets.</rule>
    <rule importance="critical">Deploy flow for raspberrypi: commit → push → ssh → pull → startup according to README.md </rule>
    <rule importance="critical">Before updating values in kubernetes/project/values/environment/service.yaml do check values.yaml of the service in kubernetes/project/charts/service/values.yaml.</rule>
    <rule importance="critical">DO NOT EDIT EXISTING CHART, the charts should be easily upgradable, try to always declare things through environment specific values file.</rule>
</rules>

## Quick Reference

**SSH Access:**
- Kyiv: `ssh andrii@raspberrypi.local`

**Routers Access:**
- Kyiv Router: `ssh andrii@kyiv-router.local`
- Wrocław Router: `ssh andrii@wroclaw-router.local`

**Service Management:**
- Read README.md for each service for specific commands.

**Key Patterns:**
- Templates in `configs/`, generated to `dockermnt/`
- All credentials in `.env` files
- Check `git status` before commits
