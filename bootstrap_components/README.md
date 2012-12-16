Dart Bootstrap Web Components POC
=================================

This is a POC to create web components for Dart, based on Twitter Bootstrap. The library provides a set of high level web components that support data binding, event handling, etc and is built on top of Dart Web UI. The ultimate goal is to create a Flex/MXML like declarative layout framework with components and layout containers.

Components
----------

**Button**

```
<x-button>Default</x-button>
<x-button disabled>Disabled</x-button>
<x-button on-click="clickHandler()">Disabled</x-button>
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
  <x-button>a</x-button>
  <x-button>b</x-button>
  <x-button>c</x-button>
  <x-button>d</x-button>
  <x-button>e</x-button>
</x-hbox>
```
