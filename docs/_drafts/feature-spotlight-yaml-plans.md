---
title: "Feature Spotlight: YAML Plans"
---

You know plans. You love plans. But did you know you can write plans in YAML?

That's right, Bolt supports the world's #1 non-programming language!

Puppet language plans are a powerful way to orchestrate complex automation workflows, but often what you need is just a simple ordered list of steps to take on different sets of nodes. That's where YAML plans shine.

Name a YAML plan just like you would a Puppet language plan, but with the `.yaml` file extension. This plan is called `postgres::install`:

```yaml
# .../modules/postgres/plans/install.yaml
parameters:
  targets:
    type: TargetSpec
  datadir:
    type: String
    default: /var/lib/pgsql/data

steps:
  - task: package
    target: $targets
    parameters:
      action: install
      name: postgresql-server
  - command: "initdb -d ${default} 2> /dev/null"
    # Let's just assume this exists
    run_as: postgres
    target: $targets
  - task: service
    target: $targets
    parameters:
      action: start
      name: postgresql
```

This plan will use the built-in package and service tasks to install and start the postgresql service, running an ad hoc command between those steps to perform the database initialization process. If any step fails, the plan will be aborted.

Plans written in YAML can pass data between steps by giving each step a `name` and then referring to that name from a future step.

```yaml
# Example of passing data between steps
```

Note the variable reference syntax copies Puppet language.

YAML offers an easy way to write straightforward plans and open up the power of Bolt to folks who aren't familiar with Puppet language. They do have some limitations though.

Unlike similar tools, Bolt doesn't support conditional logic or complex error handling in YAML. This might feel like a restriction at first, but it ensures that your simple YAML plans will _stay_ simple, rather than shoehorning control-flow contructs into a data language.

If you need more complex logic, it's time to migrate your plan to Puppet language where those features are easy. For that, you can use the `bolt plan convert` plan to automatically generate an equivalent Puppet language plan from your YAML plan. This lets you immediately get started adding the logic you need without doing any laborious manual conversion first.

You can use both YAML plans and Puppet plans in a single project and can even call out to one kind of plan from the other. With the ability to automatically migrate plans from YAML to Puppet, you can feel free to use the best tool for each job without worrying about limiting your options to grow.
