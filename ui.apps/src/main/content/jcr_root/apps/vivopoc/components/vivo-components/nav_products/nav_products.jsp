<%@page session="false"%><%--
  Copyright 1997-2009 Day Management AG
  Barfuesserplatz 6, 4001 Basel, Switzerland
  All Rights Reserved.

  This software is the confidential and proprietary information of
  Day Management AG, ("Confidential Information"). You shall not
  disclose such Confidential Information and shall use it only in
  accordance with the terms of the license agreement you entered into
  with Day.

  ==============================================================================

  Geometrixx product navigation component (supports product collections)

--%><%@ page import="java.util.Iterator,
                    java.util.ArrayList,
                    java.util.Collection,
                    org.slf4j.Logger,
                    org.apache.sling.api.resource.ResourceResolver,
                    com.day.cq.wcm.api.components.DropTarget,
                    com.day.cq.wcm.api.WCMMode,
                    com.day.cq.wcm.commons.ReferenceSearch,
                    com.day.cq.wcm.foundation.List,
                    com.adobe.cq.commerce.api.Product,
                    com.adobe.cq.commerce.api.collection.ProductCollection,
                    com.adobe.cq.commerce.api.collection.ProductCollectionManager,
                    com.adobe.cq.commerce.common.CommerceHelper,
                    java.util.HashSet,
                    java.util.Set"%><%
%><%@include file="/libs/foundation/global.jsp"%><%

    String collectionPath = properties.get("collectionPath", "");
    String listFromProp = properties.get("listFrom", "");
    boolean showCollection = "collection".equals(listFromProp);
    ProductCollectionManager pcm = resourceResolver.adaptTo(ProductCollectionManager.class);
    ProductCollection collection = pcm.getCollection(collectionPath);

    WCMMode mode = WCMMode.fromRequest(request);

    if (mode == WCMMode.EDIT) {
        //drop target css class = dd prefix + name of the drop target in the edit config
        String ddClassName = DropTarget.CSS_CLASS_PREFIX + "pages";
%><div class="<%= ddClassName %>"><%
    }

    if (properties.get("feedEnabled", false)) {
%><link rel="alternate" type="application/atom+xml" title="Atom 1.0 (List)" href="<%= resource.getPath() %>.feed" /><%
    }

    // initialize the list
%><cq:include script="init.jsp"/><%
    List list = (List)request.getAttribute("list");

    // we display eihter a foundation list or a product collection
    if (!list.isEmpty() || showCollection) {
        String cls = list.getType();
        cls = (cls == null) ? "" : cls.replaceAll("/", "");

%><%= list.isOrdered() ? "<ol" : "<ul" %> class="<%= xssAPI.encodeForHTML(cls) %>"><%
    Iterator<Page> items = (showCollection)? getProductPages(currentPage, collection, resourceResolver, log) : uniqueSKUIterator(list.getPages());
    String listItemClass = null;
    while (items.hasNext()) {
        request.setAttribute("listitem", items.next());

        if (null == listItemClass) {
            listItemClass = "first";
        } else if (!items.hasNext()) {
            listItemClass = "last";
        } else {
            listItemClass = "item";
        }
        request.setAttribute("listitemclass", " class=\"" + listItemClass + "\"");

        String script = "listitem_" + cls + ".jsp";
%><cq:include script="<%= script %>"/><%
    }
%><%= list.isOrdered() ? "</ol>" : "</ul>" %><%
    if (list.isPaginating()) {
%><cq:include script="pagination.jsp"/><%
    }
} else {
%><cq:include script="empty.jsp"/><%
    }

    if (mode == WCMMode.EDIT) {
%></div><%
    }
%>

<%!
    // For each product of a product collection returns a product page (best effort)
    // within the same language tree as the current page
    private Iterator<Page> getProductPages(Page currentPage, ProductCollection collection,
                                           ResourceResolver resolver, Logger log) {
        ArrayList<Page> plist = new ArrayList<Page>();
        Iterator<Product> products = collection.getProducts();
        if (collection != null) {
            try {
                ReferenceSearch referenceSearch = new ReferenceSearch();
                // if the component is in page: /content/geometrixx-outdoors/en/overview.html,
                // we search below: /content/geometrixx-outdoors/en
                String searchRoot = "/jcr:root" + currentPage.getAbsoluteParent(2).getPath();
                referenceSearch.setSearchRoot(searchRoot);
                while (products.hasNext()) {
                    Product product = products.next();
                    String productPath = product.getPath();
                    log.debug("-----------------------------------------------------------------------");
                    log.debug("productPath: {}", productPath);
                    Collection<ReferenceSearch.Info> resultSet = referenceSearch.search(resolver, productPath).values();
                    // loop over the product pages and take the first one that matches
                    for (ReferenceSearch.Info infoItem : resultSet) {
                        Page productPage = infoItem.getPage();
                        if (productPage != null
                                && productPage.getProperties().get("cq:productMaster", "").equals(product.getPath())
                                && productPage.getTitle().equals(product.getTitle())
                                && CommerceHelper.findCurrentProduct(productPage) != null) {
                            log.debug("productPage: {}", productPage.getPath());
                            plist.add(productPage);
                            break;
                        }
                    }
                }
            } catch (Exception e) {
                log.error("Failed to find the product pages", e);
            }
        }
        return plist.iterator();
    }

    //
    // Make sure the list only contains unique SKUs.  If two sections both contain the
    // same product we only want to show one of them.
    //
    private Iterator<Page> uniqueSKUIterator(Iterator<Page> source) {
        ArrayList<Page> result = new ArrayList<Page>();
        Set<String> SKUs = new HashSet<String>();
        while (source.hasNext()) {
            Page candidatePage = source.next();
            Product candidateProduct = CommerceHelper.findCurrentProduct(candidatePage);
            if (candidateProduct != null) {
                String candidateSKU = candidateProduct.getSKU();
                if (!SKUs.contains(candidateSKU)) {
                    result.add(candidatePage);
                    SKUs.add(candidateSKU);
                }
            }
        }
        return result.iterator();
    }

%>

