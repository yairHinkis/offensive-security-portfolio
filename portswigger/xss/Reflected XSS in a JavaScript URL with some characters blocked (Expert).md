# Write-up: PortSwigger Academy Lab – Reflected XSS in a JavaScript URL with some characters blocked (Expert)

## 1. Executive Summary
This report details the successful exploitation of a Reflected XSS vulnerability in a PortSwigger Academy Expert-level lab. The challenge required bypassing a strict Web Application Firewall (WAF) that prohibited the use of parentheses `()` and other critical characters, as well as filtering common HTML tags. The final exploit leverages JavaScript's implicit type coercion and the `throw` statement to execute an `alert()` without a direct function call.

---

## 2. Initial Reconnaissance & Fuzzing
To map the attack surface, I first tested which special characters were sanitized or blocked by the server. I injected a fuzzing string into the `postId` parameter:

`/?postId=3&<>;'\"{}()[],`

**Filter Analysis:**
* **Blocked:** `<`, `>`, `(`, `)`, `[`, `]`, `,`, `;`
* **Allowed:** `{`, `}`, `'`, `:`, `=`, `.`

The absence of parentheses `()` means that standard function invocations like `alert()` are impossible. Additionally, since `<` and `>` are blocked, we cannot break out of the JavaScript context into an HTML context (e.g., using `<img>` or `<script>` tags).

---

## 3. Context Discovery
By inspecting the page source, I identified that the input is reflected within a `fetch()` call inside a `javascript:` URI, which is the `href` attribute of a "Back to Blog" link:

`<a href="javascript:fetch('/analytics', {method:'post',body:'/post%3fpostId%3d3&[INJECTION_POINT]'}).finally(_ => window.location = '/')">Back to Blog</a>`

The payload is injected into the `body` property of the options object. To achieve XSS, I had to break out of the string literal and the object structure while maintaining valid JavaScript syntax to ensure execution.

---

## 4. Exploit Strategy

### A. Bypassing Parentheses with `throw`
In JavaScript, the `throw` statement can be used to trigger the `onerror` global event handler. By assigning `alert` to `onerror`, any thrown value will be passed to `alert` as an argument.

**The Mechanism:** `throw/**/onerror=alert,1337`

**Bypassing Spaces:** The `/**/` (empty comment) is used as a whitespace substitute because the WAF blocks literal space characters.

### B. Triggering Execution via Implicit Coercion
Since direct function calls are blocked, I used **Implicit Coercion**. By overriding the `window.toString` method and forcing a string conversion (e.g., `window + ''`), the browser automatically executes our malicious function.

---

## 5. The Final Exploit

**URL Encoded Payload:**
`.../?postId=3&%27%7D,throwFunction%3DthrowFunction%3D>%7Bthrow%2F**%2Fonerror%3Dalert%2C1337%7D%2CtoString%3DthrowFunction%2Cwindow%2B%27%27%2C%7Bx%3A%27%27`

**Decoded Logic:**
`'},throwFunction=throwFunction=>{throw/**/onerror=alert,1337},toString=throwFunction,window+'',{x:'`

### Technical Breakdown:
* `'}`: Gracefully closes the existing string and the object literal within the `fetch()` call.
* `,throwFunction=...`: Declares a global arrow function using the **Comma Operator**. This operator allows chaining multiple expressions where the syntax expects a single value.
* `throw/**/onerror=alert,1337`: Inside the function, we hijack the error handler and throw the value `1337`.
* `toString=throwFunction`: Overwrites the native `window.toString` method with our custom function.
* `window+''`: **The Trigger**. Forces the JavaScript engine to perform a string conversion, which calls our `toString` (and thus our function) without using parentheses.
* `,{x:'`: **Syntax Repair**. This opens a new object to "swallow" the remaining characters (`'}`) from the original script, ensuring the entire block remains syntactically valid.

---

## 6. Remediation
To prevent this vulnerability, the following measures should be implemented:

1.  **Input Validation:** Implement a strict allow-list for parameters like `postId` (e.g., only allowing numeric values).
2.  **Output Encoding:** Use context-aware output encoding. Since the input is reflected inside a JavaScript string, it should be Unicode-encoded (e.g., `'` becomes `\u0027`).
3.  **Content Security Policy (CSP):** Implement a strong CSP that disallows `unsafe-inline` and restricts the use of `javascript:` URIs.

---

## 7. Conclusion
This PortSwigger Expert lab demonstrates that a lack of parentheses is not a sufficient defense against XSS. By understanding the intricacies of the JavaScript engine—specifically error handling, the comma operator, and type coercion—an attacker can execute arbitrary code even in highly restricted environments.
