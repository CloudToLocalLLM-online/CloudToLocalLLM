import os
import json
import requests

API_KEY = os.getenv("LINEAR_API_KEY")
if not API_KEY:
    raise ValueError("LINEAR_API_KEY environment variable is required")

headers = {
    "Authorization": API_KEY,
    "Content-Type": "application/json",
}

query = """
query {
  issues(filter: { attachments: { source: { type: { eq: "github" } } } }) {
    nodes {
      id
      title
      description
      assignee {
        name
      }
      state {
        name
      }
      attachments {
        nodes {
          url
          source
        }
      }
    }
  }
}
"""

response = requests.post("https://api.linear.app/graphql", json={"query": query}, headers=headers)

if response.status_code == 200:
    print(json.dumps(response.json(), indent=2))
else:
    print(f"Error: {response.status_code}")
    print(response.text)