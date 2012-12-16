// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// TODO(jmesserly): html5lib might be a better home for this.
// But at the moment we only need it here.

library html5_utils;


/**
 * Maps an HTML tag to a dart:html type. This uses [htmlElementNames] but it
 * will return UnknownElement if the tag is unknown.
 */
String typeForHtmlTag(String tag) {
  var type = htmlElementNames[tag];
  // Note: this will eventually be the component's class name if it is a
  // known x-tag.
  return type == null ? 'html.UnknownElement' : type;
}

/**
 * HTML element to DOM type mapping. Source:
 * <http://dev.w3.org/html5/spec/section-index.html#element-interfaces>
 *
 * The 'HTML' prefix has been removed to match `dart:html`, as per:
 * <http://code.google.com/p/dart/source/browse/branches/bleeding_edge/dart/lib/html/scripts/htmlrenamer.py>
 * It does not appear any element types are being renamed other than the prefix.
 * However there does not appear to be the last subtypes for the following tags:
 * command, data, dialog, td, th, and time.
 */
const htmlElementNames = const {
  'a': 'html.AnchorElement',
  'abbr': 'html.Element',
  'address': 'html.Element',
  'area': 'html.AreaElement',
  'article': 'html.Element',
  'aside': 'html.Element',
  'audio': 'html.AudioElement',
  'b': 'html.Element',
  'base': 'html.BaseElement',
  'bdi': 'html.Element',
  'bdo': 'html.Element',
  'blockquote': 'html.QuoteElement',
  'body': 'html.BodyElement',
  'br': 'html.BRElement',
  'button': 'html.ButtonElement',
  'canvas': 'html.CanvasElement',
  'caption': 'html.TableCaptionElement',
  'cite': 'html.Element',
  'code': 'html.Element',
  'col': 'html.TableColElement',
  'colgroup': 'html.TableColElement',
  'command': 'html.Element', // see doc comment, was: 'CommandElement'
  'data': 'html.Element', // see doc comment, was: 'DataElement'
  'datalist': 'html.DataListElement',
  'dd': 'html.Element',
  'del': 'html.ModElement',
  'details': 'html.DetailsElement',
  'dfn': 'html.Element',
  'dialog': 'html.Element', // see doc comment, was: 'DialogElement'
  'div': 'html.DivElement',
  'dl': 'html.DListElement',
  'dt': 'html.Element',
  'em': 'html.Element',
  'embed': 'html.EmbedElement',
  'fieldset': 'html.FieldSetElement',
  'figcaption': 'html.Element',
  'figure': 'html.Element',
  'footer': 'html.Element',
  'form': 'html.FormElement',
  'h1': 'html.HeadingElement',
  'h2': 'html.HeadingElement',
  'h3': 'html.HeadingElement',
  'h4': 'html.HeadingElement',
  'h5': 'html.HeadingElement',
  'h6': 'html.HeadingElement',
  'head': 'html.HeadElement',
  'header': 'html.Element',
  'hgroup': 'html.Element',
  'hr': 'html.HRElement',
  'html': 'html.HtmlElement',
  'i': 'html.Element',
  'iframe': 'html.IFrameElement',
  'img': 'html.ImageElement',
  'input': 'html.InputElement',
  'ins': 'html.ModElement',
  'kbd': 'html.Element',
  'keygen': 'html.KeygenElement',
  'label': 'html.LabelElement',
  'legend': 'html.LegendElement',
  'li': 'html.LIElement',
  'link': 'html.LinkElement',
  'map': 'html.MapElement',
  'mark': 'html.Element',
  'menu': 'html.MenuElement',
  'meta': 'html.MetaElement',
  'meter': 'html.MeterElement',
  'nav': 'html.Element',
  'noscript': 'html.Element',
  'object': 'html.ObjectElement',
  'ol': 'html.OListElement',
  'optgroup': 'html.OptGroupElement',
  'option': 'html.OptionElement',
  'output': 'html.OutputElement',
  'p': 'html.ParagraphElement',
  'param': 'html.ParamElement',
  'pre': 'html.PreElement',
  'progress': 'html.ProgressElement',
  'q': 'html.QuoteElement',
  'rp': 'html.Element',
  'rt': 'html.Element',
  'ruby': 'html.Element',
  's': 'html.Element',
  'samp': 'html.Element',
  'script': 'html.ScriptElement',
  'section': 'html.Element',
  'select': 'html.SelectElement',
  'small': 'html.Element',
  'source': 'html.SourceElement',
  'span': 'html.SpanElement',
  'strong': 'html.Element',
  'style': 'html.StyleElement',
  'sub': 'html.Element',
  'summary': 'html.Element',
  'sup': 'html.Element',
  'table': 'html.TableElement',
  'tbody': 'html.TableSectionElement',
  'td': 'html.TableCellElement', // see doc comment, was: 'TableDataCellElement'
  'textarea': 'html.TextAreaElement',
  'tfoot': 'html.TableSectionElement',
  'th': 'html.TableCellElement', // see doc comment, was: 'TableHeaderCellElement'
  'thead': 'html.TableSectionElement',
  'time': 'html.Element', // see doc comment, was: 'TimeElement'
  'title': 'html.TitleElement',
  'tr': 'html.TableRowElement',
  'track': 'html.TrackElement',
  'u': 'html.Element',
  'ul': 'html.UListElement',
  'var': 'html.Element',
  'video': 'html.VideoElement',
  'wbr': 'html.Element',
};

/**
 * HTML element to DOM constructor mapping.
 * It is the same as [htmlElementNames] but removes any tags that map to the
 * same type, such as HeadingElement.
 * If the type is not in this map, it should use `new html.Element.tag` instead.
 */
final Map<String, String> htmlElementConstructors = (() {
  var typeCount = <int>{};
  for (var type in htmlElementNames.values) {
    var value = typeCount[type];
    if (value == null) value = 0;
    typeCount[type] = value + 1;
  }
  var result = {};
  htmlElementNames.forEach((tag, type) {
    if (typeCount[type] == 1) result[tag] = type;
  });
  return result;
})();



/**
 * HTML attributes that expect a URL value.
 * <http://dev.w3.org/html5/spec/section-index.html#attributes-1>
 *
 * Every one of these attributes is a URL in every context where it is used in
 * the DOM. The comments show every DOM element where an attribute can be used.
 */
const urlAttributes = const [
  'action',     // in form
  'cite',       // in blockquote, del, ins, q
  'data',       // in object
  'formaction', // in button, input
  'href',       // in a, area, link, base, command
  'manifest',   // in html
  'poster',     // in video
  'src',        // in audio, embed, iframe, img, input, script, source, track,
                //    video
];
