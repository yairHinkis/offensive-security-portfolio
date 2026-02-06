# Write-up: PortSwigger Academy Lab – Reflected XSS with event handlers and href attributes blocked (Expert)

## 1. Executive Summary
This report describes the discovery and exploitation of a Reflected XSS vulnerability in a highly restricted environment. The target application employed a Web Application Firewall (WAF) that blocked all standard event handlers and the `href` attribute. By leveraging **SVG SMIL** (Synchronized Multimedia Integration Language) animations, I successfully bypassed these filters to achieve arbitrary JavaScript execution.

---

## 2. Initial Reconnaissance & Fuzzing
To determine the scope of the attack surface, I performed an automated brute-force attack using Burp Suite Intruder to identify allowed HTML tags.

**Tag Analysis:**
Out of a comprehensive list of HTML tags, the following five were identified as whitelisted by the WAF:
1. `<a>`
2. `<animate>`
3. `<image>`
4. `<svg>`
5. `<title>`
<img width="1103" height="134" alt="image" src="https://github.com/user-attachments/assets/d8fe9035-b6da-41da-b2b5-32f0ce2f372f" />
<img width="1102" height="72" alt="image" src="https://github.com/user-attachments/assets/ce492e33-43fd-4032-8527-0f61b58c2486" />
<img width="1134" height="228" alt="image" src="https://github.com/user-attachments/assets/2a602743-82a4-4b61-8b16-39490f3c043d" />


**Attribute and Event Analysis:**
Further testing revealed that the WAF implemented a "deny-all" policy for:
* All `on...` event handlers (e.g., `onerror`, `onclick`, `onload`).
* The `href` attribute when used directly within an `<a>` tag.

This creates a significant challenge, as the most common vectors for XSS are explicitly neutralized.

---

## 3. Exploit Strategy: SVG SMIL Injection
Since the `href` attribute is blocked on the `<a>` tag itself, the strategy shifted to finding a way to inject or modify attributes indirectly.

SVG (Scalable Vector Graphics) is an XML-based image format that supports interactivity and animation. The `<animate>` element, part of the **SMIL specification**, allows for the dynamic modification of attributes of its parent element over time.

Crucially, many WAFs overlook the fact that an `<animate>` tag can target the `href` attribute of its parent `<a>` tag. By defining the `attributeName` as `href` and providing the payload in the `values` attribute, we can force the browser to populate the `<a>` tag with a `javascript:` URI after the initial server-side filtering has occurred.

---

## 4. The Final Exploit

**Payload:**
`<svg><a><animate attributeName="href" values="javascript:alert(1)" /><text x="20" y="20">Click me</text></a></svg>`
<img width="747" height="242" alt="image" src="https://github.com/user-attachments/assets/2876d912-0176-49dc-9a93-7afad7e2baa5" />

### Technical Breakdown:
* `<svg>`: Initializes the SVG context, which is one of the allowed tags.
* `<a>`: Defines a hyperlink element within the SVG.
* `<animate>`: **This is the core of the bypass.**
    * `attributeName="href"`: Specifies that the animation should target the `href` attribute of the parent `<a>` tag.
    * `values="javascript:alert(1)"`: Defines the value to be assigned to the targeted attribute. Because the WAF is looking for `href` inside the `<a>` tag's brackets, it fails to detect the injection occurring within the `<animate>` tag.
* `<text>`: Renders a visible string within the SVG to ensure the element is interactive.

---

## 5. Execution
When the victim clicks the text, the browser processes the SVG animation logic. The `<animate>` tag assigns the `javascript:alert(1)` string to the `<a>` tag's `href` attribute. Upon interaction, the JavaScript engine executes the `alert()` function.
 <img width="832" height="541" alt="image" src="https://github.com/user-attachments/assets/19ab2962-9196-4670-ada6-501cff703377" />

---

## 6. Remediation
To prevent this vulnerability, the following measures should be implemented:
1.  **Robust Sanitization:** Use a proven library like **DOMPurify** to sanitize HTML/SVG input. These libraries are aware of complex XML-based bypasses like SMIL.
2.  **CSP (Content Security Policy):** Implement a strict CSP that disallows `unsafe-inline` scripts and restricts the use of the `javascript:` URI scheme.
3.  **Context-Aware Filtering:** Rather than blocking specific attributes like `href`, the WAF should inspect the values of all attributes for dangerous URI schemes.

---

## 7. Conclusion
This lab highlights the limitations of black-list based filtering. While the WAF successfully blocked the `href` attribute and standard event handlers, it failed to account for the complex interactions permitted by the SVG SMIL specification. Secure coding practices should prioritize robust input sanitization over simple attribute-based filtering.
