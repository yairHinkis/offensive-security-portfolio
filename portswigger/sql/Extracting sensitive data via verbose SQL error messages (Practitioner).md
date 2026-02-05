# Write-up: PortSwigger Academy Lab – Extracting sensitive data via verbose SQL error messages (Practitioner)

## 1. Executive Summary
This report documents the exploitation of a SQL Injection vulnerability using **Error-Based** techniques. By triggering a verbose error message from the database and utilizing the `CAST` function, I was able to force the database to leak sensitive information (usernames and passwords) directly within the error response.

---

## 2. Identification and Reconnaissance
The vulnerability was identified by injecting a single quote (`'`) into a vulnerable parameter. Instead of a generic "Internal Server Error," the application returned a verbose error message containing the actual backend SQL query syntax.

When a database is configured to show detailed errors, it provides a direct feedback loop for an attacker to understand the structure of the query and the type of database in use.

<img width="206" height="88" alt="image" src="https://github.com/user-attachments/assets/4644cd73-3dff-432d-b5f7-a57283e32929" />
<img width="575" height="40" alt="image" src="https://github.com/user-attachments/assets/cbccefac-ca37-4472-89c1-e1ccd59c2e53" />

---

## 3. Methodology: The `CAST` Technique
The core of this exploit relies on causing a **"Data Type Conversion Error."** In SQL, the `CAST` function is used to convert one data type to another (e.g., converting a string to an integer).

If we attempt to `CAST` a string that does not represent a number (such as `"administrator"`) into an `int` type, the database will fail and return an error. In many cases, the error message will explicitly state the value that caused the failure:
`"invalid input syntax for type integer: 'administrator'"`

This behavior allows us to read the result of a subquery by forcing it into a failed `CAST` operation.

<img width="405" height="30" alt="image" src="https://github.com/user-attachments/assets/fceb449f-dc84-4125-8c69-35cd09455c25" />
<img width="455" height="39" alt="image" src="https://github.com/user-attachments/assets/328d63ec-16e0-4f6a-824c-a7aad47fba68" />

**This is the syntax for PostgreSQL.**
**You can find the syntax for athers SQL Databases in the grate cheet sheet of PortSwigger Academy: https://portswigger.net/web-security/sql-injection/cheat-sheet**

---

## 4. Exploitation and Data Extraction

### Step 1: Extracting Usernames
To extract the first username from the `users` table, I injected a subquery into a `CAST` function. The database executes the subquery first, retrieves the username, and then fails when it tries to convert that username into an integer.

**Payload:**
`' AND CAST((SELECT username FROM users LIMIT 1) AS int)=1`
<img width="675" height="62" alt="image" src="https://github.com/user-attachments/assets/466e1fc6-a4a1-4a6b-a2d4-078a9cdacf65" />

**The resulting error message leaked the first username:**
`"invalid input syntax for type integer: 'administrator'"`
<img width="505" height="34" alt="image" src="https://github.com/user-attachments/assets/46ead920-179d-416a-8ee2-dd1d0f09bf61" />

### Step 2: Extracting Passwords
Once the username was identified, the same logic was applied to extract the associated password by changing the column name in the subquery.

**Payload:**
`' AND CAST((SELECT password FROM users LIMIT 1) AS int)=1`
<img width="655" height="73" alt="image" src="https://github.com/user-attachments/assets/4ec6e0fc-4a17-4499-ad3b-b2d3b9261f79" />

The database returned an error containing the password string, allowing for full credential compromise.
<img width="557" height="29" alt="image" src="https://github.com/user-attachments/assets/a163618c-8439-4da7-bac0-a214ba034b9a" />

---

## 5. Remediation
To mitigate this vulnerability, the following security controls should be implemented:

1.  **Disable Verbose Errors:** Configure the application to return generic error messages to the user. Detailed database errors should only be logged internally for debugging.
2.  **Parameterized Queries:** Use prepared statements (**Parameterized Queries**) to ensure that user input is never interpreted as a SQL command.
3.  **Input Validation:** Implement strict validation on all parameters to ensure they conform to expected formats (e.g., ensuring a numeric ID is actually a number).

---

## 6. Conclusion
This lab demonstrates that even if an application does not directly display query results, verbose error messages can be just as dangerous. By understanding how the database handles data type conversion, an attacker can turn a simple error into a powerful data extraction channel.
