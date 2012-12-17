Dart Bootstrap Web Components POC
=================================

This is a POC to create web components for Dart, based on Twitter Bootstrap. The library provides a set of high level web components that support data binding, event handling, etc and is built on top of Dart Web UI. The ultimate goal is to create a Flex/MXML like declarative layout framework with components and layout containers.

Components
----------

**Button**

```
<x-button label="Default"></x-button>
<x-button label="Disabled" enabled="false"></x-button>
<x-button label="Click me" on-click="clickHandler()"></x-button>
```

**Checkbox**

```
<x-checkbox label="My Checkbox" checked="true"></x-checkbox>
<x-checkbox label="My Checkbox" on-change="changeHandler($event)"></x-checkbox>
```

**Progressbar**

```
<x-progressbar value="{{progressBarValue}}"></x-progressbar>
<x-progressbar striped="true" value="{{progressBarValue}}"></x-progressbar>
<x-progressbar striped="true" animated="true" value="{{progressBarValue}}"></x-progressbar>
```

**HBox**

```
<x-hbox padding="5" gap="10" border-style="solid" border-color="green" border-width="1">
  <x-button label="a"></x-button>
  <x-button label="b"></x-button>
  <x-button label="c"></x-button>
</x-hbox>
```

**Table**

```
<x-table striped="true" bordered="true" hover="true" condensed="true"
         columns="{{tableColumns}}" items="{{items}}"></x-table>
```
