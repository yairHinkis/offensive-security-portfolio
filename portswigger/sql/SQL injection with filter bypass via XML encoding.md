# Write-up: PortSwigger Academy Lab – SQL injection with filter bypass via XML encoding

## 1. Executive Summary
This report documents a SQL Injection vulnerability within an XML-based API endpoint. The target application implemented a Web Application Firewall (WAF) that actively filtered standard SQL injection characters (such as single quotes) and keywords. 

By leveraging **XML Entity Encoding**, I was able to obfuscate the malicious payload. The WAF inspects the raw request and fails to identify the attack, while the backend XML parser decodes the entities back into valid SQL syntax before execution, allowing for full database compromise.

---

## 2. Reconnaissance & Vulnerability Analysis
The application accepts user input via a `POST` request formatted in XML. This input is processed and subsequently used to construct a SQL query against the backend database.

<img width="437" height="233" alt="image" src="https://github.com/user-attachments/assets/354897a2-5f01-4de9-8098-3529c828cf51" />

### WAF Behavior Analysis
Initial attempts to inject standard SQL payloads revealed strict filtering rules.
* **Single Quotes:** Injecting a single quote (`'`) to break the query syntax resulted in a block/error.

<img width="1035" height="192" alt="image" src="https://github.com/user-attachments/assets/c847d4be-b0b0-4df9-83a2-e87fea8b86b8" />


* **SQL Keywords:** Injecting raw SQL keywords like `UNION` or `SELECT` was also detected and blocked by the security filter.

<img width="941" height="167" alt="image" src="https://github.com/user-attachments/assets/86666b25-f953-4229-af6c-199013ddc0bf" />

---

## 3. Exploit Strategy: The "Translation Gap"
The vulnerability lies in the discrepancy between how the WAF sees the data and how the Database Engine receives it.

1.  **The WAF** scans for literal blacklisted patterns (e.g., `'` or `UNION`).
2.  **The XML Parser** decodes XML entities (e.g., `&#x55;` -> `U`) *before* passing the data to the database.

By encoding the malicious characters into their XML numeric entity equivalents, we can "smuggle" the payload past the WAF.



---

## 4. Exploitation Workflow

### Step 1: Crafting the Bypass Payload
Using the **Hackvertor** extension in Burp Suite, I applied hex-encoding to specific characters within the payload. 

**Technique:** To evade signature-based detection, it is often sufficient to encode only the first letter of a blocked keyword. For example, converting `UNION` to `&#x55;NION`. The WAF does not recognize the string, but the XML parser reconstructs the command perfectly.

### Step 2: Database Enumeration (Version)
I injected an encoded `UNION SELECT` payload to retrieve the database version string. Note that the single quotes wrapping the payload were also encoded to bypass the filter.

**Payload Construction:**
`UNION SELECT version()` (Encoded)

<img width="1915" height="86" alt="image" src="https://github.com/user-attachments/assets/129029b0-e344-49ea-b3c8-d1455d098392" />
<img width="1498" height="219" alt="image" src="https://github.com/user-attachments/assets/3b6fadb0-0bc8-417c-9dbf-e91cb02d323b" />

### Step 3: Data Exfiltration (Users & Passwords)
After confirming the injection, I modified the payload to extract sensitive credentials from the `users` table.

**Payload Construction:**
`UNION SELECT username || '~' || password FROM users` (Encoded)

<img width="980" height="201" alt="image" src="https://github.com/user-attachments/assets/30613c39-712d-4df4-934b-1d7d15c3389c" />
<img width="1033" height="181" alt="image" src="https://github.com/user-attachments/assets/b34523c5-f8d2-4bbc-ad75-3447be953f31" />

<img width="400" height="226" alt="image" src="https://github.com/user-attachments/assets/67b537c3-89a9-4aa1-a345-0bec33741726" />
<img width="293" height="153" alt="image" src="https://github.com/user-attachments/assets/d0cd9271-8454-4c9e-9920-34e5092cd100" />

---

## 5. Remediation
To mitigate this vulnerability, the following measures should be implemented:

1.  **Parameterized Queries:** Ensure that all user input is handled via prepared statements, regardless of the input format (XML/JSON).
2.  **Input Validation Layering:** Input validation should occur *after* the XML parsing stage, not before, to ensure the filter inspects the actual data being processed.
3.  **Least Privilege:** Limit database user permissions to prevent access to system tables.

---

## 6. Conclusion
This lab demonstrates that "Input Sanitization" is context-dependent. A filter that works perfectly for plain text may fail completely against structured data formats like XML if it does not account for the decoding process of the parser.
