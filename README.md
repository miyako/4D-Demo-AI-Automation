# Event Pulse — 4D AI Demo

An event management application built with [4D](https://www.4d.com/) that demonstrates how to integrate AI capabilities (OpenAI) into a business workflow. The app manages corporate event planning — weather contingency and client modification handling — powered by LLM reasoning, semantic search, and tool calling.

## Getting Started

### Prerequisites

- **4D v21 R3** or later
- An **OpenAI API key** (for AI features)
- **macOS** — this application has been tested on macOS only

### Tested AI Models

| Alias | Model | Usage |
|-------|-------|-------|
| `chat-reasoning` | `gpt-5.5` | Complex reasoning and decision-making |
| `chat-simple` | `gpt-4o` | Lightweight operations |
| `embedding` | `text-embedding-3-small` | Service catalog semantic search |

### Installation

1. **Clone** the repository:
   ```bash
   git clone https://github.com/<your-org>/4D-Demo-AI-Automation.git
   ```

2. **Open** the project in 4D by selecting `Project/4D-Demo-AI-Automation.4DProject`.

3. **Configure your OpenAI API key** — the `AIProviders.json` file is gitignored, so you need to set up your credentials. Use one of these options:

   - **4D Settings** (recommended) — accessible from the Home screen UI, or via **Settings > AI** in 4D. Configure the OpenAI provider from there.
   - **Manual file** — create `Project/Sources/AIProviders.json`:
     ```json
     {
       "providers": {
         "openai": {
           "baseURL": "https://api.openai.com/v1",
           "apiKey": "sk-proj-YOUR_KEY_HERE"
         }
       },
       "models": {
         "chat-reasoning": { "provider": "openai", "model": "gpt-5.5" },
         "chat-simple":    { "provider": "openai", "model": "gpt-4o" },
         "embedding":      { "provider": "openai", "model": "text-embedding-3-small" }
       }
     }
     ```

4. **Run** the project. The **Home** form opens automatically.

5. **Seed the database** — click the **Init** button on the Home screen to load demo data (clients, venues, services, events, and emails). From there you can navigate to Events, Services, and Venues.

### Demo Data

The `Resources/data/` folder contains seed files loaded on first run:

| File | Records | Description |
|------|---------|-------------|
| `clients.json` | 97 | Companies with contact info |
| `venues.json` | 132 | Worldwide venues (capacity, coordinates, indoor/outdoor) |
| `services.json` | 116 | Services across 14 categories with pricing |
| `events.json` | 150 | Mix of confirmed, quoted, and completed events |
| `emails.json` | 109 | Sample emails (quotes, modifications, info requests) |

---

## About the Application

### Data Model

```
Client (1) ──── (N) Event
Venue  (1) ──── (N) Event
Event  (1) ──── (N) EventLine
Service (1) ──── (N) EventLine
Event  (1) ──── (N) Email
```

Six tables with UUID primary keys manage the relationships between clients, venues, services, event line items, and emails.

### AI Scenarios

The application showcases two concrete AI-driven scenarios:

1. **Weather Contingency** — For upcoming outdoor events, the app fetches weather forecasts via [Open-Meteo](https://open-meteo.com/) and asks the AI to propose contingency actions (move indoors, add tenting).

2. **Modification Handling** — When a client sends a change request, the AI identifies the target event (handling ambiguity), evaluates cost impacts, and suggests adjustments.

### AI Architecture

| Component | Role |
|-----------|------|
| **AIAdvisor** | Orchestrates LLM calls (reasoning via o4-mini, lightweight via GPT-4o) with JSON Schema validation |
| **ServiceMatcher** | Semantic search over the service catalog using `text-embedding-3-small` vector embeddings |
| **Tool_SearchServices** | AI tool — finds matching services for an event brief |
| **Tool_CalculateCost** | AI tool — computes exact costs (prevents LLM arithmetic errors) |
| **EventLogger** | Logs all AI interactions (prompts, responses, tool calls) per event per day |

AI integration is provided by [**4D AIKit**](https://github.com/4d/4D-AIKit) component, declared as a dependency in `dependencies.json` and fetched automatically by the 4D dependency manager.

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
