---
title: Writing advanced tasks
difficulty: Intermediate
time: Approximately 10 minutes
---

In this exercise you will write a task with metadata.

# Prerequisites
Complete the following before you start this lesson:

1. [Installing Bolt](../01-installing-bolt)
1. [Acquiring nodes](../02-acquiring-nodes)
1. [Writing tasks](../05-writing-tasks)

# About task metadata
Task metadata files describe task parameters, validate input, and control how tasks are executed.  Adding metadata to your tasks helps others use them.  You write metadata for a task in JSON and save it with the same name as your task. For example, if you write a task called `great_metadata.py` its corresponding metadata file is named `great_metadata.json`.

# Writing your first task with metadata
Write a simple task that formats the parameters a user gives it.

Save the following file to `modules/exercise8/tasks/great_metadata.py`:

```python
{% include_relative modules/exercise8/tasks/great_metadata.py -%}
```

Write the accompanying metadata and save the file to `modules/exercise8/tasks/great_metadata.json`. Specify the parameters as types such as `"type": "Integer"`  which help validate user input as an `Integer`.

```json
{% include_relative modules/exercise8/tasks/great_metadata.json -%}
```

# Using your task with metadata

Run 'bolt task show' to verify that the task you created appears with its description in the list of available tasks.

```shell
bolt task show --modulepath ./modules
```

The result:

```plain
...
exercise8::great_metadata     An exercise in writing great metadata
facter_task                   Inspect the value of system facts
install_puppet                Install the puppet 5 agent package
...
```

Run `bolt task show <task-name>` to view the parameters that your task uses.

```shell
bolt task show exercise8::great_metadata --modulepath ./modules
```

The result:

```plain
exercise8::great_metadata - An exercise in writing great metadata

USAGE:
bolt task run --nodes <node-name> exercise8::great_metadata name=<value> recursive=<value> action=<value> timeout=<value> [--noop]

PARAMETERS:
- name: String
    The description for the 'name' parameter
- recursive: Boolean
    The description for the 'recursive' parameter
- action: Enum[stop, start, restart]
    The description for the 'action' parameter
- timeout: Optional[Integer]
    The description for the 'timeout' parameter

MODULE:
tasks-hands-on-lab/08-writing-advanced-tasks/modules/exercise8
```

# Testing your task's metadata validation

Bolt can use the types that you have specified in your metadata to validate parameters passed to your task.  Run your task with an incorrect value for the `action` parameter and see what happens.

Run your task and pass the following parameters as a JSON string.

```shell
bolt task run exercise8::great_metadata --nodes all --modulepath ./modules --params '{"name":"poppey","action":"spinach","recursive":true}'
```

The result:

```plain
Task exercise8::great_metadata:
 parameter 'action' expects a match for Enum['restart', 'start', 'stop'], got 'spinach'
```

Correct the value for the action parameter and run the task again.

```shell
bolt task run exercise8::great_metadata --nodes node1 --modulepath ./modules --params '{"name":"poppey","action":"start","recursive":true}'
```

The result:

```plain
Started on node1...
Finished on node1:
  {
    "message": "\nCongratulations on writing your metadata!  Here are\nthe keys and the values that you passed to this task.\n",
    "parameters": [
      {
        "type": "unicode",
        "value": "start",
        "key": "action"
      },
      {
        "type": "unicode",
        "value": "exercise8::great_metadata",
        "key": "_task"
      },
      {
        "type": "unicode",
        "value": "poppey",
        "key": "name"
      },
      {
        "type": "bool",
        "value": true,
        "key": "recursive"
      }
    ]
  }
Successful on 1 node: node1
Ran on 1 node in 0.97 seconds
```

# Creating a task that supports no-operation mode (noop)

You can write tasks that support no-operation mode (noop). You use noop to see what changes a task would make, but without taking any action.

Create the metadata for the new task and save it to `modules/exercise8/tasks/file.json`:

```json
{% include_relative modules/exercise8/tasks/file.json -%}
```

Save the following file to `modules/exercise8/tasks/file.py`. This task uses input from stdin. When a user passes the `--noop` flag, the JSON object from stdin will contain the `_noop` key with a value of True.

```python
{% include_relative modules/exercise8/tasks/file.py -%}
```

Test the task with the `--noop` flag.

```shell
bolt task run exercise8::file --nodes node1 --modulepath ./modules content=Hello_World filename=/tmp/hello_world --noop
```

The result:

```plain
Started on node1...
Finished on node1:
  {
    "_noop": true,
    "success": true
  }
Successful on 1 node: node1
Ran on 1 node in 0.96 seconds
```

Run the task again without `--noop` and see the task create the file successfully.

```shell
bolt task run exercise8::file --nodes node1 --modulepath ./modules content=Hello_World filename=/tmp/hello_world
```

The result:

```plain
Started on node1...
Finished on node1:
  {
    "success": true
  }
Successful on 1 node: node1
Ran on 1 node in 0.98 seconds
```

# Next steps

Now that you know how to write task metadata and include the `--noop` flag you can move on to:

1. [Writing advanced Plans](../09-writing-advanced-plans)
