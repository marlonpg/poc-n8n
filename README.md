# What is n8n?

n8n (pronounced "n-eight-n") is a workflow automation platform for connecting apps, APIs, and data so repetitive work runs automatically.

In short:
- Build automations visually (low-code), then add code when needed.
- Connect many services (500+ integrations, plus custom API calls).
- Run in n8n Cloud or self-host for more control and privacy.
- Use it for classic automation and AI-powered workflows.

## Why people use it

- Automate cross-tool tasks (for example: forms -> database -> Slack alerts).
- Create reliable business workflows with triggers, logic, and error handling.
- Add custom JavaScript/Python for advanced logic.
- Keep control of infrastructure and security with self-hosting options.

## Good starting points

- Docs home: https://docs.n8n.io/
- About n8n: https://docs.n8n.io/
- Quickstart: https://docs.n8n.io/try-it-out/
- Choosing Cloud vs self-host: https://docs.n8n.io/choose-n8n/
- Product website: https://n8n.io/
- Integrations: https://n8n.io/integrations/

## Setup (quick local option)

If you want to run n8n locally fast, Docker is the easiest path.

1. Install Docker Desktop.
2. Run n8n:

```bash
docker run -it --rm -p 5678:5678 docker.n8n.io/n8nio/n8n
```

3. Open http://localhost:5678 in your browser.
4. Create your owner account when prompted.

Alternative: use n8n Cloud if you don't want local infrastructure.

## Run an example workflow ("Hello n8n")

1. In n8n, create a new workflow.
2. Add a `Manual Trigger` node.
3. Add an `Edit Fields (Set)` node.
4. In the Set node, add a field:
	- Name: `message`
	- Value: `Hello from n8n`
5. Connect `Manual Trigger -> Edit Fields (Set)`.
6. Click `Execute workflow`.
7. Check the output data in the Set node. You should see `message: "Hello from n8n"`.

## More references

- Very quick quickstart: https://docs.n8n.io/try-it-out/quickstart/
- First workflow tutorial: https://docs.n8n.io/try-it-out/tutorial-first-workflow/
- Docker install docs: https://docs.n8n.io/hosting/installation/docker/
