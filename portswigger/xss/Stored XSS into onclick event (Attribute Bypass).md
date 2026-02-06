# Write-up: PortSwigger Academy Lab – Stored XSS into onclick event (Attribute Bypass)(Expert level)

## 1. Executive Summary
This report details the discovery and exploitation of a **Stored XSS** vulnerability within a comment section. Despite defenses that escape single quotes and backslashes, the application remains vulnerable because it reflects user input inside an HTML event handler attribute. By leveraging **HTML Entity Encoding**, I successfully bypassed the server-side filters to achieve arbitrary JavaScript execution.

---

## 2. Vulnerability Analysis
The vulnerability is located in the **"Website"** field of the comment submission form. When a comment is rendered, the URL provided is embedded directly into an `onclick` event handler:

`<a id="author" href="/posts/..." onclick="var tracker={trackClick}; tracker('/path/to/link');">Author Name</a>`

**Filter Analysis:**
* Angle brackets (`<`, `>`) and Double quotes (`"`) are HTML-encoded.
* Single quotes (`'`) and Backslashes (`\`) are escaped with a backslash (e.g., `'` becomes `\'`).

If a user attempts to inject a single quote (`'`) to terminate the string, the filter modifies it to `\'`. Since backslashes are also escaped, it is not possible to use a double backslash to neutralize the escape character.

---

## 3. The Bypass: HTML Entity Decoding
The bypass leverages the fundamental way web browsers process HTML attributes. Event handlers (such as `onclick`) are treated as HTML attributes. According to the HTML specification, browsers must **decode HTML entities** within these attributes *before* the resulting string is passed to the JavaScript engine for execution.

By using the HTML entity `&apos;` (which represents a single quote), we can circumvent the server-side security filter:
1.  The server-side filter treats `&apos;` as a literal string of characters rather than a quote, so it is **not** escaped.
2.  When the page is rendered, the browser identifies the `&apos;` within the `onclick` attribute.
3.  The browser decodes `&apos;` into a literal single quote (`'`) in the DOM.
4.  The JavaScript engine subsequently executes the decoded, malicious payload.

---

## 4. Exploitation Methodology

### Step 1: Intercepting the Request
Submit a comment and intercept the `POST` request using an intercepting proxy (e.g., Burp Suite). Identify the `website` parameter in the request body.
<img width="726" height="89" alt="image" src="https://github.com/user-attachments/assets/4bc8aa28-536f-4063-bea4-e604fffdee9d" />
<img width="649" height="158" alt="image" src="https://github.com/user-attachments/assets/902eb757-b692-47d2-ab65-f35e1ca06206" />

### Step 2: Payload Construction
The payload must satisfy several conditions:
* It must begin with a valid protocol (e.g., `http://`) to pass basic URL validation.
* It must close the existing JavaScript function call using a single quote.
* It must execute the malicious command (`alert`).
* It must handle the remaining characters using a comment (`//`) to ensure no syntax errors occur.

**Payload:**
`http://example.com?&apos;);alert(1);//`

---

## 5. Execution Logic
When a victim interacts with the link, the browser processes the attribute as follows:

**Raw Source (Server Output):**
`onclick="var tracker={...}; tracker('http://example.com?&apos;);alert(1);//');"`

**Processed DOM (Browser Interpretation):**
`onclick="var tracker={...}; tracker('http://example.com?');alert(1);//');"`

The `&apos;` effectively terminates the `tracker()` function, allows `alert(1)` to run as a separate statement, and the `//` comments out the trailing single quote and parenthesis, maintaining script integrity.
<img width="600" height="55" alt="image" src="https://github.com/user-attachments/assets/8646b71a-73b1-46e0-89d7-ab17a18ce172" />
<img width="545" height="381" alt="image" src="https://github.com/user-attachments/assets/8bbf6d40-964b-4117-90d8-227ec9d42b23" />

---

## 6. Remediation
To mitigate this vulnerability, the following measures should be implemented:
1.  **Context-Aware Encoding:** Use security libraries that apply specific encoding based on the output context (HTML body vs. HTML attribute vs. JavaScript).
2.  **Content Security Policy (CSP):** Implement a strict CSP that prohibits inline event handlers (`unsafe-inline`). This forces the use of `addEventListener`, which is not susceptible to this specific attribute-based injection.
3.  **Input Validation:** Enforce a strict whitelist for the "Website" field, allowing only legitimate URL structures and protocols.

---

## 7. Conclusion
This lab demonstrates that server-side escaping is often insufficient if the context of the reflection (HTML attributes) performs its own decoding. Understanding the **order of operations** between the browser's HTML parser and the JavaScript engine is critical for both attacking and defending modern web applications.
